package CallBackery::Plugin::Users;
use Mojo::Base 'CallBackery::PluginTable';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);

=head1 NAME

CallBackery::Plugin::Users - User Plugin

=head1 SYNOPSIS

 use CallBackery::Plugin::Users;

=head1 DESCRIPTION

The User Plugin.

=cut


=head1 METHODS

All the methods of L<CallBackery::PluginForm> plus:

=cut

=head2 tableCfg


=cut

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('UserId'),
            type => 'str',
            width => '1*',
            key => 'user_id',
            sortable => $self->true,
        },
        {
            label => trm('Username'),
            type => 'str',
            width => '3*',
            key => 'user_login',
            sortable => $self->true,
        },
        {
            label => trm('Given Name'),
            type => 'str',
            width => '4*',
            key => 'user_given',
            sortable => $self->true,            
        },
        {
            label => trm('Family Name'),
            type => 'str',
            width => '4*',
            key => 'user_family',
            sortable => $self->true,     
        },
        {
            label => trm('Note'),
            type => 'str',
            width => '8*',
            key => 'user_note',
        },
     ]
};

=head2 actionCfg

=cut

has actionCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('Add User'),
            action => 'popup',
            name => 'userFormAdd',
            popupTitle => trm('New User'),
            backend => {
                plugin => 'UserForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit User'),
            action => 'popup',
            name => 'userFormEdit',
            popupTitle => trm('Edit User'),
            backend => {
                plugin => 'UserForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete User'),
            action => 'submitVerify',
            question => trm('Do you really want to delete the selected user ?'),
            key => 'delete',
            handler => sub {
                my $args = shift;
                my $id = $args->{selection}{user_id};
                die mkerror(4992,"You have to select a user first")
                    if not $id;
                die mkerror(4993,"You can not delete the user you are logged in with")
                    if $id == $self->user->userId;
                my $db = $self->user->db;
                $db->deleteData('user',$id);
                return { 
                    action => 'reload'
                };
            }
        },
    ];
};

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $dbh = $self->user->db->dbh;
    return ($dbh->selectrow_array('SELECT count(user_id) FROM user'))[0];
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $dbh = $self->user->db->dbh;
    my $SORT ='';
    if ($args->{sortColumn}){
        $SORT = 'ORDER BY '.$dbh->quote_identifier($args->{sortColumn});
        $SORT .= $args->{sortDesc} ? ' DESC' : ' ASC';
    }
    return $dbh->selectall_arrayref(<<"SQL",{Slice => {}}, $args->{lastRow}-$args->{firstRow},$args->{firstRow});
SELECT user_id,user_login, user_given, user_family, user_note
FROM user
$SORT
LIMIT ? OFFSET ?
SQL
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

Copyright (c) 2014 by OETIKER+PARTNER AG. All rights reserved.

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

