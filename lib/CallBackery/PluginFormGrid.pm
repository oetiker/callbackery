package CallBackery::PluginFormGrid;
use Carp qw(carp croak);
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Data::Dumper;

=head1 NAME

CallBackery::PluginFormFGrid - Reporter base class

=head1 SYNOPSIS

 use CallBackery::PluginFormGrid;

=head1 DESCRIPTION

The base class for reporter reporters.

=cut

use Mojo::Base 'CallBackery::PluginForm';

=head1 ATTRIBUTES

The attributes of the L<CallBackery::PluginForm> class and these:

=head2 screenCfg

Returns a Configuration Structure for the Grid Form. It is basically the same as for a normal form.
But this one uses the grid formatter for the form, requiering each form element including action buttons
to be placed explicitly into a grid.

=cut

has screenCfg => sub {
    my $self = shift;
    my $screen = $self->SUPER::screenCfg;
    $screen->{type} = 'formGrid';
    $screen->{grid} = $self->gridCfg
    return $screen;
};

=head2 gridCfg

Returns a grid configuration hash. The keys are the set commands from the C<qx.ui.layout.Grid> object.
The values can be scalars (for single argument methods), arrays (for multi argument methods) and arrays
of arrays to call the same method with different arguments.

 has gridCfg => sub {
    my $self = shift;
    return {
        setColumnFlex => [
            [ 1,2 ],
            [ 2,2 ],
        ],
        setSpacing => 10,
        setRowHeight => [ 1, 10 ],
    }
 };

=head2 actionCfg

On top of the arguments required from the L<CallBackery::PluginForm> C<actionCfg>
each action must specify a layout property which will be passed on to the
C<qx.ui.layout.Grid> object for rendering the action buttion.

=head2 formCfg

Each standard form element must provide a C<lableLayout> and a C<fieldLayout> property.
For the C<header> widget, no C<fieldLayout> is required.

=cut

has gridCfg => sub {
    return {}
}

1;
__END__

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 COPYRIGHT

Copyright (c) 2013 by OETIKER+PARTNER AG. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2013-12-16 to 1.0 first version

=cut

# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et

