package CallBackery::Plugin::UserForm;
use Mojo::Base 'CallBackery::PluginForm';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::Util qw(hmac_sha1_sum);

=head1 NAME

CallBackery::Plugin::UserForm - UserForm Plugin

=head1 SYNOPSIS

 use CallBackery::Plugin::UserForm;

=head1 DESCRIPTION

The UserForm Plugin.

=cut


=head1 METHODS

All the methods of L<CallBackery::PluginForm> plus:

=cut

=head2 formCfg

Returns a Configuration Structure for the Report Frontend Module.

=cut

my $DUMMY_PASSWORD = '>>NOt REALly a PaSSwoRd<<';

has formCfg => sub {
    my $self = shift;
    return [
        $self->config->{type} eq 'edit' ? {
            key => 'user_id',
            label => trm('UserId'),
            widget => 'text',
            set => {
                readOnly => $self->true,
            },
        } : (),

        {
            key => 'user_login',
            label => trm('Login'),
            widget => 'text',
            set => {
                required => $self->true,
            },
        },
        {
            key => 'user_password',
            label => trm('Password'),
            widget => 'password',
            set => {
                required => $self->true,
            },
        },
        {
            key => 'user_password_check',
            label => trm('Password Again'),
            widget => 'password',
            set => {
                required => $self->true,
            },
        },

        {
            key => 'user_given',
            label => trm('Given Name'),
            widget => 'text',
            set => {
                required => $self->true,
            }            
        },
        {
            key => 'user_family',
            label => trm('Family Name'),
            widget => 'text',
            set => {
                required => $self->true,
            }            
        },
        {
            key => 'user_note',
            label => trm('Note'),
            widget => 'textArea',
            set => {
                placeholder => 'some extra information about this user',
            }            
        },
    ];
};

has actionCfg => sub {
    my $self = shift;
    my $mode = $self->config->{mode} // 'default';
    my $type = $self->config->{type} // 'new';

    my $handler = sub {
        my $args = shift;
        my @fields = qw(login family given note);
        if ($args->{user_password} ne $DUMMY_PASSWORD){
            die mkerror(2847,"The password instances did not match.")
                if $args->{user_password} ne $args->{user_password_check};
            push @fields, 'password';
        }
        $args->{user_password} = hmac_sha1_sum($args->{user_password});
        my $db = $self->user->db;
        my $id = $db->updateOrInsertData('user',{
            map { $_ => $args->{'user_'.$_} } @fields
        },$args->{user_id} ? { id => int($args->{user_id}) } : ());
        if ($self->controller and $self->controller->can('runEventActions')){
            $self->controller->runEventActions('changeConfig');
        }
        return {
            action => $mode eq 'init' ? 'logout' : 'dataSaved'
        };
    };

    return [
        {
            label => $mode eq 'init' 
               ? trm('Create Admin Account')
               : $type eq 'edit' 
               ? trm('Save Changes') 
               : trm('Add User'),
            action => 'submit',
            key => 'save',
            handler => $handler
        }
    ];
};

has grammar => sub {
    my $self = shift;
    $self->mergeGrammar(
        $self->SUPER::grammar, 
        {
            _doc => "User Form Configuration",
            _vars => [ qw(type mode) ],
            type => {
                _doc => 'type of form to show: edit, add',
                _re => '(edit|add)'
            },
            mode => {
                _doc => 'In init mode the for will run for the __ROOT user and thus allow the creation of the initial account',
                _re => '(init|default)',
                _re_error => 'Pick one of init or default',
                _default => 'default'
            }
        },
    );
};

has checkAccess => sub {
    my $self = shift;
    my $userId = $self->user->userId;
    my $mode = $self->config->{mode} // 'default';
    if ($mode eq 'init'){
        return ($userId and $userId eq '__ROOT');
    }
    return $self->SUPER::checkAccess;
};


sub getAllFieldValues {
    my $self = shift;
    my $args = shift;
    return {} if $self->config->{type} ne 'edit';
    my $id = $args->{selection}{user_id};
    return {} unless $id;

    my $db = $self->user->db;
    my $data = $db->fetchRow('user',{id => $id});
    $data->{user_password} = $DUMMY_PASSWORD;
    $data->{user_password_check} = $DUMMY_PASSWORD;

    return $data;
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

