use strict;
use warnings;

use Test::More tests => 2;
use Test::TCP;
use JSON;
use Net::Twitter::UserStreams;

use Test::Requires qw(Plack::Builder Plack::Handler::Twiggy Try::Tiny);
use Test::Requires { 'Plack::Request' => '0.99' };

foreach my $enable_chunked (0, 1) {
    test_tcp(
        client => sub{
            my $port = shift;

            my $got_list = 0;
            
            local $AnyEvent::Twitter::Stream::USERSTREAM_SERVER = "127.0.0.1:$port";
            local $AnyEvent::Twitter::Stream::US_PROTOCOL       = "http";

            my $listener;$listener = Net::Twitter::UserStreams->new(
                token => 'dummy',
                token_secret => 'dummy',
                consumer_key => 'dummy',
                consumer_secret => 'dummy',
                wait => 1,
                reconnect => 1,
                handlers => {
                    on_friends_list => sub{
                	$got_list++;
        		$listener->stop if $got_list >= 2; #if retried,got over 2 lists
                    },
        	    on_error => sub {
        		die @_;
        	    }
                },
            );
            $listener->run;
            ok $got_list >= 2, "retry";
        },
        server => sub{
            my $port = shift;
            run_streaming_server($port, $enable_chunked);
        }
    );
}

sub run_streaming_server{
    my ($port,$chunked) = @_;

    my $user_stream = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);

        return sub {
            my $respond = shift;

            my $writer = $respond->([200, [
                'Content-Type' => 'application/json',
                'Server' => 'Jetty(6.1.17)',
            ]]);

            $writer->write(encode_json({friends => [123,234,345]}) . "\x0D\x0A");
        };
    };

    my $app = builder {
        enable 'Chunked' if $chunked;
        mount '/2/' => $user_stream;
    };
    
    my $server = Plack::Handler::Twiggy->new(
        host => '127.0.0.1',
        port => $port,
    )->run($app);
}
