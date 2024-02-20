package CallBackery::Command::showconfig;

use Mojo::Base 'Mojolicious::Command', -signatures;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Pod::Usage;
use Pod::Simple::Text;
use Pod::Simple::HTML;

has description => "showconfig\n";
has usage       => <<"EOF";
Usage: $0 showconfig [options]

  --verbose
  --help
  --html     output as html

EOF

my %opt;

sub run ($self, @args) {
    my $app = $self->app;

    GetOptionsFromArray \@args, \%opt,qw(help verbose html) or exit 1;

    $app->log->level($opt{verbose} ? 'debug' : 'info');

    if ($opt{help}) { die $self->usage }

    $opt{html} ? Pod::Simple::HTML->filter(\$app->config->pod)
               : Pod::Simple::Text->filter(\$app->config->pod);


    return;
}

1;

__END__

=head1 NAME

showconfig - show config documentation as pod

=head1 SYNOPSIS

APPLICATION B<showconfig> [--verbose] [--help] [--html]

=head1 DESCRIPTION

Parse the .cfg file definition and output documentation as pod

=head1 COPYRIGHT

Copyright (c) 2024- by OETIKER+PARTNER AG. All rights reserved.

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

S<Fritz Zaucker E<lt>fritz.zaucker@oetiker.chE<gt>>

=head1 HISTORY

 2024-02-19 fz Initial

=cut
