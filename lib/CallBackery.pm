package CallBackery;

=head1 NAME

CallBackery - Appliance Frontend Builder

=head1 SYNOPSIS

 reqquire Mojolicious::Commands;
 Mojolicious::Commands->start_app('CallBackery');

=head1 DESCRIPTION

Configure the mojo engine to run our application logic as webrequests arrive.

=head1 ATTRIBUTES

=cut

use strict;
use warnings;

# load the two modules to have perl check them
use Mojolicious::Plugin::Qooxdoo;
use Mojo::URL;
use Mojo::JSON;
use Mojo::Util qw(hmac_sha1_sum slurp);
use CallBackery::RpcService;
use CallBackery::Config;
use CallBackery::Plugin;
use CallBackery::DocPlugin;

our $VERSION = '0.1.2';

use Mojo::Base 'Mojolicious';

=head2 config

A hash pointer to the configuration object. See L<CallBackery::Config> for details.
The default configuration file is located in etc/afb.cfg. You can override the
path by setting the C<{CallBackery_CONF> environment variable.

The config property is set automatically on startup.

=cut

has 'config' => sub {
    my $self = shift;
    my $conf = CallBackery::Config->new(
        app => $self,
        file => $ENV{CallBackery_CONF}
            || $self->home->rel_file('etc/afb.cfg')
    );
};

=head1 METHODS

All  the methods of L<Mojolicious> as well as:

=cut

=head2 startup

Mojolicious calls the startup method at initialization time.

=cut

sub startup {
    my $self = shift;

    # we have some more commands here
    unshift @{$self->commands->namespaces},__PACKAGE__.'::Command';

    my $gcfg = $self->config->cfgHash->{BACKEND};
    $self->log->path($gcfg->{log_file});
    if ($gcfg->{log_level}){
        $self->log->level($gcfg->{log_level});
    }

    # properly figure your own path when running under fastcgi
    $self->hook( before_dispatch => sub {
        my $c = shift;
        my $reqEnv = $c->req->env;
        my $uri = $reqEnv->{SCRIPT_URI} || $reqEnv->{REQUEST_URI};
        my $path_info = $reqEnv->{PATH_INFO};
        $uri =~ s|/?${path_info}$|/| if $path_info and $uri;
        $c->req->url->base(Mojo::URL->new($uri)) if $uri;
    });

    # a bunch of headers for making us more secure
    # inspired by google+ headers (2014-10-31)

    my $SecurityHeaders = {
        'X-Frame-Options' => 'SAMEORIGIN',
        'X-XSS-Protection' => '1; mode=block',
        'X-Content-Type-Options' => 'nosniff',
        'Cache-Control' => 'private, max-age=0' 
    };

    $self->hook( after_dispatch => sub {
        my $c = shift;
        for my $header ( keys %$SecurityHeaders){
            $c->res->headers->header($header,$SecurityHeaders->{$header});
        }
    });

    # on initial startup lets get all the 'stuff' into place
    # reconfigure will also create the secretFile.
    if (not -f $self->config->secretFile){
        $self->config->reConfigure;
    }

    $self->secrets([slurp $self->config->secretFile]);

    my $routes = $self->routes;

    $self->plugin('CallBackery::DocPlugin', {
        root => '/doc',
        index => 'CallBackery::Index',
        localguide => $gcfg->{localguide},
        template => Mojo::Asset::File->new(
            path=>$self->home->rel_file('templates/doc.html.ep')
        )->slurp,
    });
    
    $routes->route('/upload')->to(controller => 'RpcService', action => 'handleUpload');
    $routes->route('/download')->to(controller => 'RpcService', action => 'handleDownload');

    $self->plugin('qooxdoo',{
        path => 'QX-JSON-RPC',
        namespace => 'CallBackery',
        controller => 'RpcService'
    });

    return 0;
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

 2013-12-06 to 1.0 first version

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
