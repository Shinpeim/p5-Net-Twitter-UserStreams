use strict;
use warnings;

use Test::More tests=>14;
use Test::TCP;

use Net::Twitter::UserStreams;
use YAML;
use JSON;

use Test::Requires qw(Plack::Builder Plack::Handler::Twiggy Try::Tiny);
use Test::Requires { 'Plack::Request' => '0.99' };

my ($friends_list,$delete,$tweet,$fav,$unfav,$follow,$dm) = YAML::LoadFile("t/data/data.yml");


foreach my $enable_chunked (0, 1) {
    test_tcp(
        client => sub{
            my $port = shift;
            
            local $AnyEvent::Twitter::Stream::STREAMING_SERVER  = "127.0.0.1:$port";
            local $AnyEvent::Twitter::Stream::USERSTREAM_SERVER = "127.0.0.1:$port";
            local $AnyEvent::Twitter::Stream::US_PROTOCOL       = "http";
            my $listener;$listener = Net::Twitter::UserStreams->new(
        	token => 'dummy',
        	token_secret => 'dummy',
        	consumer_key => 'dummy',
        	consumer_secret => 'dummy',
        	wait => 1,
        	handlers => {
        	    on_friends_list => sub{
        		is_deeply $_[0],$friends_list,"friend_list";
        	    },
        	    on_tweet => sub{
        		is_deeply $_[0],$tweet,"tweet";
        	    },
        	    on_delete => sub{
        		is_deeply $_[0],$delete,"delete";
        	    },
        	    on_favorite => sub{
        		is_deeply $_[0],$fav,'fav';
        	    },
        	    on_unfavorite => sub{
        		is_deeply $_[0],$unfav,'unfav';
        	    },
        	    on_follow => sub{
        		is_deeply $_[0],$follow,'follow';
        	    },
        	    on_direct_message => sub{
        		is_deeply $_[0],$dm,'dm';
        		$listener->stop;
        	    },
        	},
            );
            $listener->run;
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

            for my $data (($friends_list,$delete,$tweet,$fav,$unfav,$follow,$dm)) {
        	$writer->write(encode_json($data) . "\x0D\x0A\n");
        	sleep 1;
            }
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
