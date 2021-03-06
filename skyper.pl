#!/usr/bin/perl
# $Id: skyper.pl,v 1.1 2012/08/14 19:01:53 cameron Exp cameron $
use 5.006;
use strict;
use warnings;

package Ckxng::Skype::Logger;

our $VERSION = '1.002';

=head1 NAME

skyper.pl (Ckxng::Skype::Logger)

=head1 VERSION

1.002

=head1 SYNOPSIS

    ./skyper.pl [-dhisVv] [-T subject] [-f file] [-t tag] [-c chat] [message]
    
=head1 DESCRIPTION

Pure-perl implemenation of the Skype messaging API.  This script can only
send to chats.

This was written to improve access for my team while working as a contractor
and is permissively licensed.  See LICENSE.

Options:

=over 4

=item B<-i, --id>

Log the process ID of the logger process with each line.

=item B<-f, --file file>

Log the contents of the specified file.  This option cannot be combined with a
command-line message.

=item B<-h, --help>

Display a help text and exit.

=item B<-s, --stderr>

Output the message to standard error as well as to the system log.

=item B<-t, --tag tag>

Mark every line to be logged with the specified tag.
This is the subject line of the ticket if B<--ticket> is used.

=item B<-V, --version>

Display version information and exit.

=item B<-v, --verbose>

Output additional diagnistic messages to stderr

=item B<-T, --ticket queue>

The ticket queue to send this message to.  B<--chat> then becomes the chatroom
that recieves the acknowledgement of ticket creation.

=item B<-c, --chat chatroom> [REQUIRED]

The chat name to send the message to.

=item B<-->

End the argument list. This is to allow the message to start with a hyphen (-).

=item B<message>

Write the message to log; if not specified, and the -f flag is not provided,
standard input is logged.

=back

The logger utility exits 0 on success, and >0 if an error occurs.

=head1 REQUIRES

=over 4

=item L<ZeroLag::ZCAPI>, lib ver. 1.0.1+

=item L<Getopt::Long>

=item L<Pod::Usage>

=back

=head1 EXPORT

None by default.

=cut

############################################################

=head1 SUBROUTINES

=head2 B<< $self->new >>()

Create a Logger object with default $self->{args}

=cut

sub new {
  my $package = shift(@_);
  my $self = {
    args => {
      id       => undef,
      chat     => undef,
      ticket   => undef,
      file     => undef,
      stderr   => undef,
      tag      => undef,
      verbose  => undef,
      help     => undef,
      version  => undef,
      argv     => undef,
    },
  };

  use ZeroLag::ZCAPI;
  $self->{api} = ZeroLag::ZCAPI->new();
  $self->{api}->connect('http://hyperion.example.com:9999/astra/zcapi') or die "unable to connect to astra\n";
  $self->{api}->setApiKey('X') or die "unable to set api key\n";

  return(bless($self, $package));
}

=head2 B<run>()

Run the logger with the behavior specified by $self->{args}

=cut

sub run {
  my $self = shift(@_);

  die "-c is required\n" unless $self->{args}->{chat};

  my $prefix = '';
  $prefix = $self->{args}->{tag} if $self->{args}->{tag};
  $prefix .= "[$$]" if $self->{args}->{id};
  $prefix .= ": " if $prefix;
  $prefix = '' if $self->{args}->{ticket};

  my $api_method = 'send_message';
  $api_method = 'api_passthru' if $self->{args}->{ticket};

  my $message = '';
  $message = "!rt add_ticket\nset queue: $self->{args}->{ticket}\n" if $self->{args}->{ticket};
  $message .= "set subject: $self->{args}->{tag}\n" if($self->{args}->{ticket} && $self->{args}->{tag});

  my $response = undef;
  if($self->{args}->{file}) {
    die "file unreadable\n" unless -r $self->{args}->{file};
    open READF, $self->{args}->{file} or die "unable to open file\n";
    my $message = '';
    close READF;

    $message .= $_ while(<READF>);
    print STDERR $prefix . $message if $self->{args}->{stderr};
    $response = $self->{api}->exec($api_method, [$self->{args}->{chat}, $prefix . $message]);
    die "unable to send message! ". $self->{api}->getErrorMessage ."\n" if $self->{api}->hasError || !$response || $response ne 'OK';
  } elsif($self->{args}->{argv}) {
    print STDERR $prefix . join(" ", @{ $self->{args}->{argv} }) . "\n" if $self->{args}->{stderr};
    $response = $self->{api}->exec($api_method, [$self->{args}->{chat}, $prefix . join(" ", @{ $self->{args}->{argv} }) . "\n"]);
    die "unable to send message! ". $self->{api}->getErrorMessage ."\n" if $self->{api}->hasError || !$response || $response ne 'OK';
  } else {
    $message .= $_ while(<STDIN>);
    print STDERR $prefix . $message if $self->{args}->{stderr};
    $response = $self->{api}->exec($api_method, [$self->{args}->{chat}, $prefix . $message]);
    die "unable to send message! ". $self->{api}->getErrorMessage ."\n" if $self->{api}->hasError || !$response || $response ne 'OK';
  }
}

############################################################

=head1 MAIN SUBROUTINES

=head2 B<main_version>()

Print version information found in the documentation.

-V will print version information

=head2 B<main_help>()

Print usage information found in the documentation.

-h will print basic usage

-hv will load the man page

=head2 B<main>()

Extracts commandline arguments and initializes the application and
$self->{args}.  Runs the application.

-vvv will dump the args to stderr.

=cut

sub main_version {
  use Pod::Usage;
  print pod2usage(-verbose=>99, -sections=>[qw( NAME VERSION AUTHOR COPYRIGHT LICENSE)]);
  exit;
}

sub main_help {
  use Pod::Usage;
  print $_[0]?pod2usage(-verbose=>99, -sections=>[qw( SYNOPSIS DESCRIPTION )]):pod2usage;
  exit;
}

sub main {
  use Getopt::Long;
  Getopt::Long::Configure "bundling";
  my $app = ZeroLag::Skype::Logger->new;
  GetOptions($app->{args},
    "id|i",
    "chat|c=s",
    "ticket|T=s",
    "file|f=s",
    "priority|p=s",
    "stderr|s",
    "tag|t=s",
    "verbose|v+",
    "version|V",
    "help|h",
  );
  @{ $app->{args}->{argv} } = @ARGV if $#ARGV >= 0;
  if($app->{args}->{verbose} && $app->{args}->{verbose} >= 3) {
    print map { sprintf("*%s: %s\n", $_, $app->{args}->{$_}||"") } keys(%{$app->{args}});
  }
  main_help $app->{args}->{verbose} if $app->{args}->{help};
  main_version if $app->{args}->{version};
  $app->run;
}
main unless caller;

=head1 META

This module must be run on a server that is also running the Skype client.
Don't forget that the $ENV{DISPLAY} variable must be set!

=head1 AUTHOR

Cameron King <http://cameronking.me>

=head1 COPYRIGHT

Copyright 2012 Cameron C. King.  All rights reserved.

=head1 LICENSE

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY CAMERON C. KING ''AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL CAMERON C. KING OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.

=cut
1;

