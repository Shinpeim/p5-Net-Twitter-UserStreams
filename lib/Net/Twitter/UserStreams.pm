package Net::Twitter::UserStreams;
use strict;
use warnings;
our $VERSION = '0.02';

use AnyEvent::Twitter::Stream;
use Smart::Args;

$SIG{PIPE} = 'IGNORE';
$SIG{HUP}  = 'IGNORE';
$ENV{ANYEVENT_TWITTER_STREAM_SSL} = 1;

sub new {
    args my $class,
         my $token           => {isa => 'Str'},
         my $token_secret    => {isa => 'Str'},
         my $consumer_key    => {isa => 'Str'},
         my $consumer_secret => {isa => 'Str'},
         my $wait            => {isa => 'Int', default => 30},
         my $handlers        => {isa => 'HashRef[CodeRef]', default => {}};

    my $self = bless {
        token => $token,
        token_secret => $token_secret,
        consumer_key => $consumer_key,
        consumer_secret => $consumer_secret,
        wait => $wait,
        handlers => $handlers,
        running => 0,
        cv => AnyEvent->condvar,
    }, $class;

    for my $meth (qw/on_tweet on_favorite on_unfavorite on_delete on_follow on_direct_message on_friends_list/){
        $self->{handlers}->{$meth} ||= sub{};

        no strict 'refs';
        no warnings 'redefine';
        * {__PACKAGE__ . '::' . $meth} = sub{
            args_pos my $self,
                     my $code => {isa => 'CodeRef'};
            $self->{handlers}->{$meth} = $code;
        };
    }

    $self;
}

sub stop{
    my $self = shift;

    #stop infinity loop
    $self->{running} = 0;

    #stop event_loop
    $self->{cv}->send;
}

sub run {
    my $self = shift;
    $self->{running} = 1;

    while ($self->{running}) {
        my $listener = AnyEvent::Twitter::Stream->new(
            consumer_key    => $self->{consumer_key},
            consumer_secret => $self->{consumer_secret},
            token           => $self->{token},
            token_secret    => $self->{token_secret},
            method          => 'userstream',
            on_event        => sub{
                my $event = $_[0];
                my $meth = 'on_'.$event->{event};

                if (defined $self->{handlers}->{$meth} && ref $self->{handlers}->{$meth} eq 'CODE') {
                    $self->{handlers}->{$meth}->(@_);
                }
                else {
                    warn "no such method $meth";
                }
            },
            on_tweet        => sub {
                if ($_[0]->{'friends'}) {
                    $self->{handlers}->{'on_friends_list'}->(@_);
                }
                elsif ($_[0]->{'delete'}) {
                    $self->{handlers}->{'on_delete'}->(@_);
                }
                elsif ($_[0]->{'direct_message'}) {
                    $self->{handlers}->{'on_direct_message'}->(@_);
                }
                else {
                    $self->{handlers}->{'on_tweet'}->(@_);
                }
            },
            on_error        => sub {
                $self->{cv}->send;
            },
        );
        $self->{cv}->recv;
        sleep($self->{wait});
    }
}

1;
__END__

=head1 NAME

Net::Twitter::UserStreams - Receive Twitter UserStreams API

=head1 SYNOPSIS

  use strict;
  use warnings;

  use FindBin;
  use lib "$FindBin::RealBin/../lib";

  use Config::Pit;
  use Net::Twitter::UserStreams;
  use YAML;

  my $args = Config::Pit::get("Net-Twitter-UserStreams", require => {
      'token' => "your access token on twitter",
      'token_secret' => "your access token secret on twitter",
      'consumer_key' => "your consumer key on twitter",
      'consumer_secret' => "your consumer secret on twitter",
  });

  #setup
  my $listener = Net::Twitter::UserStreams->new(
      token           => $args->{token},
      token_secret    => $args->{token_secret},
      consumer_key    => $args->{consumer_key},
      consumer_secret => $args->{consumer_secret},
      wait => 10,        #wait time for reconnect (optional)

      # handlers are optional. when ommited,it does nothing.
      handlers => {
          on_friends_list => sub{
              my $list = shift;
              warn Dump $list;
          },
          on_tweet => sub{
              my $tweet = shift;
              warn Dump $tweet;
          },
          on_delete => sub{
              my $deleted_tweet = shift;
              warn Dump $deleted_tweet;
          },
      },
  );

  #you can set handlers after create object
  $listener->on_favorite(sub{
      my $faved_tweet = shift;
      warn Dump $faved_tweet;
  });

  $listener->on_unfavorite(sub{
      my $unfaved_tweet = shift;
      warn Dump $unfaved_tweet;
  });

  $listener->on_follow(sub{
      my $unfaved_tweet = shift;
      warn Dump $unfaved_tweet;
  });

  $listener->on_direct_message(sub{
      my $dm = shift;
      warn Dump $dm;
  });

  # then you can run the listener
  $listener->run;


=head1 DESCRIPTION

Net::Twitter::UserStreams is a simple wrapper of L<AnyEvent::Twitter::Stream>

=head1 AUTHOR

Shinpei Maruyama E<lt>shinpeim@gmail.comE<gt>

=head1 SEE ALSO

L<AnyEvane::Twitter::Stream>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
