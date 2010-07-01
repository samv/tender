#!/usr/bin/perl -w

package Bot::BasicBot::Pluggable::Module::Standup;

use strict;
use base qw( Bot::BasicBot::Pluggable::Module );

use List::Util qw( shuffle );


sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{standups} = {};
    return $self;
}

# a standup is:
#   channel
#   last to join
#   who's gone
#   parking lot
#   start time
#   stop time

sub help { q{whassap} }

sub told {
    my ($self, $message) = @_;
    my $logger = Log::Log4perl->get_logger( ref $self );

    # Only care if we're addressed.
    return if !$message->{address};

    my ($command, $rest) = split / /, $message->{body}, 2;
    $command = lc $command;
    $message->{command} = $command;
    $message->{rest} = $rest;

    my $work = {
        hi      => q{hi},
        standup => q{standup},
        start   => q{start},
        q{next} => q{next_person},
    }->{$command};
    return if !$work;

    return $self->can($work)->($self, $message);
}

sub hi {
    my ($self, $message) = @_;
    return 'o hai.';
}

sub standup {
    my ($self, $message) = @_;

    my $channel = $message->{rest};
    return "Start a standup in which channel? Try 'standup <channel>'." if !$channel;
    return "'$channel' doesn't look like a channel name to me. Try 'standup <channel>'."
        if $channel !~ m{ \A # \w+ \z }xms;
    return "There's already a standup in $channel." if $self->{standups}->{$channel};

    $self->{standups}->{$channel} = { channel => $channel };
    my $logger = Log::Log4perl->get_logger( ref $self );
    $logger->debug("STANDUP self is $self, a " . ref($self));
    $logger->debug("STANDUP bot is " . $self->bot . ", a " . ref($self->bot));
    $self->bot->join($channel);
    $self->say(
        channel => $channel,
        body => q{Time for standup! Tell me 'start' when everyone's here.},
    );

    return q{};
}

sub start {
    my ($self, $message) = @_;

    my $channel = $message->{channel};
    return "What? There's no standup here!" if !$channel;
    my $state = $self->{standups}->{$channel};
    return "There's not currently a standup here." if !$state;

    $state->{gone} = {};
    return $self->next_person($message);
}

sub next_person {
    my ($self, $message) = @_;
    my $logger = Log::Log4perl->get_logger( ref $self );

    my $channel = $message->{channel};
    return "What? There's no standup here!" if !$channel;
    my $state = $self->{standups}->{$channel};
    return "There's not currently a standup here." if !$state;

    my %ignore = map { $_ => 1 } $self->bot->ignore_list;
    my $me = $self->bot->nick;

    my @names = $self->bot->names($channel);
    $logger->debug("I see these folks in $channel: " . join(q{ }, @names));
    @names = grep {
        !$state->{gone}->{$_} && !$ignore{$_} && !$me
    } @names;
    $logger->debug("Minus all the chickens that's: " . join(q{ }, @names));

    return $self->done($message) if !@names;

    my ($next, undef) = shuffle @names;
    $state->{gone}->{$next} = 1;
    $logger->debug("I picked $next to go next");

    $self->bot->say(
        channel => $channel,
        address => $next,
        body => q{your turn},
    );

    return q{};
}

sub done {
    my ($self, $message) = @_;

    my $channel = $message->{channel};
    return "What? There's no standup here!" if !$channel;
    my $state = $self->{standups}->{$channel};
    return "There's not currently a standup here." if !$state;

    $self->bot->say(
        channel => $channel,
        body => q{All done!},
    );

    return q{};
}

sub tick {
    return 0;
}

1;
