package CallBackery::Command::config;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Pod::Usage;
use Data::Dumper;
use Mojo::Util qw(slurp);
use Term::ReadKey;

has description => "commandline config interface\n";
has usage       => <<"EOF";
usage: $0 config *function* 
   
   backup [backup.afb]     write a backup file
   restore [backup.afb]    read a backup file
   re-configure            rewrite all configuration files
   un-configure            clear all configuration

commandline interface to backup, restore and reconfiguration

EOF

use vars qw(%opt);

# caching variables
my %cache;
my %opt;

sub run {
    my ($self, @args) = @_;
    my $app = $self->app;

    GetOptionsFromArray \@args, \%opt,qw(help verbose password=s) or exit 1;

    $app->log->path('/dev/stderr');
    $app->log->level($opt{verbose} ? 'debug' : 'warn');

    if ($opt{help})     { die $self->usage }
 
    my $cmd = shift @args or die $self->usage;

    my $cfg = $self->app->config;

    for ($cmd){
        /^backup$/ && do {
            my $file = shift @args;
            my $password = $self->getPassword();
            my $config = $cfg->getConfigBlob($password);
            if ($file){
                if (open my $fh, '>', $file){
                    binmode($fh);
                    print $fh $config;
                }
                else {
                    die "Writing to $file: $!";
                }
            }
            else {
                print $config;
            }
            last;
        };
        /^restore$/ && do {
            my $file = shift @args;
            my $password = $self->getPassword();
            $cfg->restoreConfigBlob($file ? slurp $file : join('',<STDIN>),$password);
            last;
        };
        /^re-configure$/ && do {
            system qw(service tty1 stop);
            $cfg->reConfigure;
            system qw(service tty1 start);
            last;
        };
        /^un-configure$/ && do {
            system qw(service tty1 stop);
            system qw(service afb stop);
            $cfg->unConfigure;
            warn "Un-Configuration complete. Please shutdown the System.\n";
            last;
        };
        die "ERROR: unknown command $_\n".$self->usage;
    }
}

sub getPassword {
    my $self = shift;
    return $opt{password} if exists $opt{password};
    print STDERR "Backup password: ";
    ReadMode('noecho');
    my $password = <STDIN>;
    chomp($password);
    ReadMode(0);
    print STDERR "\n";
    return $password;
}

1;

__END__

=head1 NAME

config.pm - commandline configure interface

=head1 SYNOPSIS

afb.pl B<config> I<command> [I<file>]

   backup [backup.afb]     write a backup file
   restore [backup.afb]    read a backup file
   re-configure            rewrite all configuration files
   un-configure            clear all configuration


=head1 DESCRIPTION

Command line configuration script for CallBackery.

=head1 COPYRIGHT

Copyright (c) 2014 by OETIKER+PARTNER AG. All rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY 

 2014-02-24 to Initial

=cut
