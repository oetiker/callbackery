package CallBackery::Command::shell;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Pod::Usage;
use Data::Dumper;
use Term::ReadLine;
use Term::UI;

has description => "query for basic ip configuration\n";
has usage       => <<"EOF";
usage: $0 shell

interactive configuration shell

EOF

use vars qw(%opt);

# caching variables
my %cache;
my %opt;

has term => sub {
    Term::ReadLine->new('screen');
};

sub run {
    my ($self, @args) = @_;
    my $app = $self->app;

    GetOptionsFromArray \@args, \%opt,qw(help verbose) or exit 1;

    # walk the plugins and see if userId __CONSOLE gets any access
    $app->log->path('/dev/stderr');
    $app->log->level($opt{verbose} ? 'debug' : 'warn');
    my $cfg = $self->app->config;
    my $cfgHash = $cfg->cfgHash;
    my $user = CallBackery::User->new(controller=>$self,userId=>'__SHELL');
    for my $name (@{$cfgHash->{PLUGIN}{list}}){
        my $obj = eval {
            $cfg->instanciatePlugin($name,$user);
        } or next;
        for (1){
            my $data = $self->ask($obj);
            eval {
                $self->action($obj,$data);
            };
            if ($@){
                print $@;
                next;
            }
            last;
        }
    }
    # just to be sure, rewrite and restart everything
    $self->app->config->reConfigure;
}

sub ask {
    my $self = shift;
    my $plugin = shift;
    my $screen = $plugin->screenCfg;
    my %data;

    if ($screen->{type} eq 'form'){
        my $title = "Config for ".$plugin->tabName;
        print "\n".$title."\n".('=' x length($title))."\n";
        for my $item (@{$screen->{form}}){
            for ($item->{widget}){
                /header/ && do {
                    print "\n".$item->{label}."\n".('-' x length($item->{label}))."\n";
                    last;
                };
                /text/ && do {
                    my $prompt = $item->{label};
                    my $default = $plugin->getFieldValue($item->{key});
                    if ($item->{set}{readOnly}){
                        print "\n".$prompt.': '.$default."\n\n";
                        last;
                    }
                    elsif ($item->{set}{placeholder}){
                        $prompt .= ' (eg '.$item->{set}{placeholder}.')';
                    }
                    $data{$item->{key}} = $self->term->get_reply(
                        prompt => $prompt.": ",
                        default => $default,
                        allow => sub {
                            my $value = shift ||'';
                            my $error = $plugin->validateData($item->{key},{$item->{key} => $value});
                            if ($error){
                                $Term::UI::INVALID = $error.': ';
                                return 0;
                            }
                            return 1;
                        }
                    );
                    last;
                };
            }
        }
        return \%data;
     }
}

sub action {
    my $self = shift;
    my $plugin = shift;
    my $actions = $plugin->screenCfg->{action} || [];
    my $data = shift;
    my %choices;
    my @choiceNames;
    for my $item (@$actions){
        next unless $item->{action} =~ /submit/;
        my $label = $item->{label};
        $choices{$label} = $item;
        push @choiceNames, $label;
    }
    print "\n";
    push @choiceNames, 'Exit';
    my $reply = $self->term->get_reply(
                    prompt => 'What would you like todo next?',
                    choices => \@choiceNames,
                    default => 'Exit',
    );
    exit if $reply eq 'Exit';
    my $ret = $choices{$reply}{handler}($data);
    print "\n\n*** ".$ret->{message}." ***\n\n";
}

1;

__END__

=head1 NAME

shell.pm - Interactive configuration shell

=head1 SYNOPSIS

afb.pl B<shell>

=head1 DESCRIPTION

Interactive configuration script. The command runs with userId __SHELL. Only plugins with
access for __SHELL will become active.

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
