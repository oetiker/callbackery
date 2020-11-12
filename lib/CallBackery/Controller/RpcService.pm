package CallBackery::Controller::RpcService;

use Mojo::Base qw(Mojolicious::Plugin::Qooxdoo::JsonRpcController);
use CallBackery::Exception qw(mkerror);
use CallBackery::Translate qw(trm);

use CallBackery::User;
# use Data::Dumper;
use Scalar::Util qw(blessed weaken);
use Mojo::JSON qw(encode_json decode_json from_json);

=head1 NAME

CallBackery::RpcService - RPC services for CallBackery

=head1 SYNOPSIS

This module gets instantiated by L<CallBackery> and provides backend functionality.

=head1 DESCRIPTION

This module provides the following methods

=cut

# the name of the service we provide
has service => 'default';

=head2 allow_rpc_access(method)

is this method accessible?

=cut

my %allow = (
    getBaseConfig => 1,
    login => 1,
    logout => 1,
    ping => 1,
    getUserConfig => 2,
    getPluginConfig => 3,
    validatePluginData => 3,
    processPluginData => 3,
    getPluginData => 3,
    getSessionCookie => 2
);

has config => sub {
    shift->app->config;
};

has user => sub {
    my $self = shift;
    my $obj = $self->app->userObject->new(controller=>$self,log=>$self->log);
    #
    weaken $obj->{controller};
    return $obj;
};

has pluginMap => sub {
    my $map = shift->config->cfgHash->{PLUGIN};
    return $map;
};


sub allow_rpc_access {
    my $self = shift;
    my $method = shift;
    if (not $self->req->method eq 'POST') {
        # sorry we do not allow GET requests
        $self->log->error("refused ".$self->req->method." request");
        return 0;
    }
    if (not exists $allow{$method}){
        return 0;
    }

    for ($allow{$method}){
        /1/ && return 1;
        /3/ && do {
            my $plugin = $self->rpcParams->[0];
            if ($self->instantiatePlugin($plugin)->mayAnonymous){
                return 1;    
            }
        };
        return $self->user->isUserAuthenticated;
    }
    return 0;
};

# dataCleaner($data)

has passMatch => sub {
    qr{(?i)(?:password|_pass)};
};

sub perMethodCleaner {
    my $self = shift;
    my $method = shift or return;
    return {
        login => sub {
            my $data = shift;
            if (ref $data eq 'ARRAY'){
               $data->[1] = 'xxx';
            }
            return;
        }
    }->{$method};
};

sub dataCleaner {
    my $self = shift;
    my $data = shift;
    my $method = shift;

    if (my $perMethodCleaner = $self->perMethodCleaner($method)){
        return $perMethodCleaner->($data);
    }
    
    my $match = $self->passMatch;
    my $type = ref $data;
    for ($type) {
        /ARRAY/ && do {
            $self->dataCleaner($_) for @$data;
        };
        /HASH/ && do {
            for my $key (keys %$data) {
                my $value = $data->{$key};
                if ($key =~ /$match/){
                    $data->{$key} = 'xxx';
                }
                elsif (ref $value){
                    $self->dataCleaner($value);
                }
            }
        }
    }
}

=head2 logRpcCall

set CALLBACKERY_RPC_LOG for extensive logging messages. Note that all values with keys matching /password|_pass/ do get replaced with 'xxx' in the output.

=cut

# our own logging
sub logRpcCall {
    my $self = shift;
    if ($ENV{CALLBACKERY_RPC_LOG}){
        my $method = shift;
        my $data = shift;
        $self->dataCleaner($data,$method);
        my $userId = eval { $self->user->loginName } // '*UNKNOWN*';
        my $remoteAddr = $self->tx->remote_address;
        $self->log->debug("[$userId|$remoteAddr] CALL $method(".encode_json($data).")");
    }
    else {
        $self->SUPER::logRpcCall(@_);
    }
}

=head2 logRpcReturn

set CALLBACKERY_RPC_LOG for extensive logging messages. Note that all values with keys matching /password|_pass/ do get replaced with 'xxx' in the output.

=cut

# our own logging
sub logRpcReturn {
    my $self = shift;
    if ($ENV{CALLBACKERY_RPC_LOG}){
        my $data = shift;
        $self->dataCleaner($data);
        my $userId = eval { $self->user->loginName } // '*UNKNOWN*';
        my $remoteAddr = $self->tx->remote_address;
        $self->log->debug("[$userId|$remoteAddr] RETURN ".encode_json($data).")");
    }
    else {
        $self->SUPER::logRpcReturn(@_);
    }

}

=head2 ping()

check if the server is happy with our authentication state

=cut

sub ping {
    return 'pong';
}

=head2 getSessionCookie()

Return a timeestamped session cookie. For use in the X-Session-Cookie header or as a xsc field
in form submissions. Note that session cookies for form submissions are only valid for 2 seconds.
So you have to get a fresh one from the server before submitting your form.

=cut

sub getSessionCookie {
    shift->user->makeSessionCookie();
}

=head2 getConfig()

get some gloabal configuration information into the interface

=cut

sub getBaseConfig {
    my $self = shift;
    return $self->config->cfgHash->{FRONTEND};
}

=head2 login(user,password)

Check login and provide the user specific interface configuration as a response.

=cut

sub login { ## no critic (RequireArgUnpacking)
    my $self = shift;
    my $login = shift;
    my $password = shift;
    my $cfg = $self->config->cfgHash->{BACKEND};
    my $ok = $self->user->login($login,$password);
    if (eval { blessed $ok && $ok->isa('Mojo::Promise') }){
        my $ret = Mojo::Promise->new;
        $ok->then(
            sub {
                if (shift){
                    $ret->resolve({            
                        sessionCookie => $self->user->makeSessionCookie()
                    });
                }
                else {
                    $ret->resolve(undef);
                }
            },
            sub {
                $ret->reject(@_);
            }
        );
        return $ret;
    }
    if ($ok) {
        return {
            sessionCookie => $self->user->makeSessionCookie()
        };
    }
    return undef;
}

=head2 logout

Kill the session.

=cut

sub logout {
    my $self = shift;
    $self->session(expires=>1);
    return 'http://youtu.be/KGsTNugVctI';
}



=head2 instantiatePlugin

get an instance for the given plugin

=cut

sub instantiatePlugin {
    my $self = shift;
    my $name = shift;
    my $args = shift;
    my $user = $self->user;
    my $plugin = $self->config->instantiatePlugin($name,$user,$args);
    $plugin->log($self->log);
    return $plugin;
}

=head2 processPluginData(plugin,args)

handle form sumissions

=cut

sub processPluginData {
    my $self = shift;
    my $plugin = shift;
    # creating two statements will make things
    # easier to debug since there is only one
    # thing that can go wrong per line.
    my $instance = $self->instantiatePlugin($plugin);
    return $instance->processData(@_);
}

=head2 validateField(plugin,args)

validate the content of the given field for the given plugin

=cut

sub validatePluginData {
    my $self = shift;
    my $plugin = shift;
    return $self->instantiatePlugin($plugin)
        ->validateData(@_);
}

=head2 getPluginData(plugin,args);

return the current value for the given field

=cut

sub getPluginData {
    my $self = shift;
    my $plugin = shift;
    return $self->instantiatePlugin($plugin)
        ->getData(@_);
}


=head2 getUserConfig

returns user specific configuration information

=cut

sub getUserConfig {
    my $self = shift;
    my $args = shift;
    my @plugins;
    my $ph = $self->pluginMap;
    for my $name (@{$ph->{list}}){
        my $obj = eval {
            $self->instantiatePlugin($name,$args);
        };
        warn "$@" if $@;
        next unless $obj;
        push @plugins, {
            tabName => $obj->tabName,
            name => $obj->name,
            instantiationMode => $obj->instantiationMode
        };
    }
    return {
        userInfo => $self->user->userInfo,
        plugins => \@plugins,
    };
}

=head2 getPluginConfig(plugin,args)

returns a plugin configuration removing all the 'back end' keys and non ARRAY or HASH
references in the process.

=cut

sub getPluginConfig {
    my $self = shift;
    my $plugin = shift;
    my $args = shift;
    my $obj = $self->instantiatePlugin($plugin,$args);
    return $obj->filterHashKey($obj->screenCfg,'backend');
}

=head2 runEventActions(event[,args])

Call the eventAction handlers of all configured plugins. Currently the following events
are known.

   changeConfig

=cut

sub runEventActions {
    my $self = shift;
    my $event = shift;
    for my $obj (@{$self->config->configPlugins}){
        weaken $obj->controller($self)->{controller};
        if (my $action = $obj->eventActions->{$event}){
            $action->(@_)
        }
    }
}

=head2 setPreDestroyAction(key,callback);

This can be used to have tasks completed at the end of a webtransaction since
the controller gets instantiated per transaction.
An example application would be backing up the configuration changes only
once even if more than one configChange event has occured.

=cut

my $runPreDestroyActions = sub {
    my $self = shift;
    my $actions = $self->{preDestroyActions} // {};
    $self->log->debug('destroying controller');
    for my $key (keys %$actions){
        $self->log->debug('running preDestroyAction '.$key);
        eval {
            $actions->{$key}->();
        };
        if ($@){
            $self->log->error("preDestoryAction $key: ".$@);
        }
        # and thus hopefully releasing the controller
        delete $actions->{$key};
    }
    delete $self->{preDestroyActions}
};

sub setPreDestroyAction {
    my $self = shift;
    my $key = shift;
    my $cb = shift;
    if (not $self->{preDestroyActions}){
        # we want to run these pretty soon, basically as soon as
        # controll returns to the ioloop
        Mojo::IOLoop->timer("0.2" => sub{ $self->$runPreDestroyActions });
    }
    $self->{preDestroyActions}{$key} = $cb;
}

sub DESTROY {
    my $self = shift;
    eval { $self->helper->log->debug('Destroying RpcService controller'); };
}



=head2 handleUpload

Process incoming upload request. This is getting called via a route and NOT
in the usual way, hence we  have to render our own response!

=cut


sub handleUpload {
    my $self = shift;
    if (not $self->user->isUserAuthenticated){
        return $self->render(json => {exception=>{
            message=>trm('Access Denied'),code=>4922}});
    }
    my $name = $self->req->param('name');
    if (not $name){
        return $self->render(json => {exception=>{
            message=>trm('Plugin Name missing'),code=>3934}});
    }

    my $upload = $self->req->upload('file');
    if (not $upload){
        return $self->render(json => {exception=>{
            message=>trm('Upload Missing'),code=>9384}});
    }
    my $obj = $self->config->instantiatePlugin($name,$self->user);

    my $form;
    if (my $formData = $self->req->param('formData')){
        $form = eval { decode_json($formData) };
        if ($@){
           return $self->render(json=>{exception=>{
               message=>trm('Data Decoding Problem %1',$@),code=>7932}});
        }
    }
    $form->{uploadObj} = $upload;

    my $return = eval {
        $obj->processData({
            key => $self->req->param('key'),
            formData => $form,
        });
    };
    if ($@){
        if (blessed $@){
            if ($@->isa('CallBackery::Exception')){
                return $self->render(json=>{exception=>{
                    message=>$@->message,code=>$@->code}});
            }
            elsif ($@->isa('Mojo::Exception')){
                return $self->render(json=>{exception=>{message=>$@->message,code=>9999}});
            }
        }
        return $self->render(json=>{exception=>{message=>$@,code=>9999}});
    }
    if (eval { blessed $return and $return->isa('Mojo::Promise')}){
        $return->then(sub {
            $self->render(json=>shift);
        },
        sub {
            my $err = shift;
            if (blessed $err){
                if ($err->isa('CallBackery::Exception')){
                    return $self->render(json=>{exception=>{message=>$err->message,code=>$err->code}});
                }
                elsif ($err->isa('Mojo::Exception')){
                    return $self->render(json=>{exception=>{message=>$err->message,code=>9999}});
                }
            }
            return $self->render(json=>{exception=>{message=>$err,code=>9999}});
        });
        $self->render_later;
        return $return;
    }
    #warn Dumper $return;
    $self->render(json=>$return);
}

=head2 handleDownload

Process incoming download request. The handler expects two parameters: name
for the plugin instance and formData for the data of the webform.

The handler getting the request must return a hash with the following elements:

=over

=item filename

name of the download when saved

=item type

mime-type of the download

=item asset

a L<Mojo::Asset>. eg C<Mojo::Asset::File->new(path => '/etc/passwd')>.

=back

=cut

sub handleDownload {
    my $self = shift;

    if (not $self->user->isUserAuthenticated){
        return $self->render(json=>{exception=>{
            message=>trm('Access Denied'),code=>3928}});
    }

    my $name = $self->param('name');
    my $key = $self->param('key');
    if (not $name){
        return $self->render(json=>{exception=>{
            message=>trm('Plugin Name missing'),code=>3923}});
    }

    my $obj = $self->config->instantiatePlugin($name,$self->user);

    my $form;
    if (my $formData = $self->req->param('formData')){
        $form = eval { from_json($formData) };
        if ($@){
            return $self->render(json=>{exception=>{
                message=>trm('Data Decoding Problem %1',$@),code=>3923}});
        }
    }
    my $map = eval {
        $obj->processData({
            key => $key,
            formData => $form,
        });
    };
    if ($@){
        if (blessed $@){
            if ($@->isa('CallBackery::Exception')){
                return $self->render(json=>{exception=>{
                    message=>$@->message,code=>$@->code}});
            }
            elsif ($@->isa('Mojo::Exception')){
                return $self->render(json=>{exception=>{
                    message=>$@->message,code=>9999}});
            }
        }
        return $self->render(json=>{exception=>{message=>$@,code=>9999}});
    }
    if (eval { blessed $map and $map->isa('Mojo::Promise')}){
        $map->then(sub {
            my $map = shift;
            $self->res->headers->content_type($map->{type}.';name=' .$map->{filename});
            $self->res->headers->content_disposition('attachment;filename='.$map->{filename});
            $self->res->content->asset($map->{asset});
            $self->rendered(200);
        },
        sub {
            my $err = shift;
            if (blessed $err){
                if ($err->isa('CallBackery::Exception')){
                    return $self->render(json=>{exception=>{message=>$err->message,code=>$err->code}});
                }
                elsif ($err->isa('Mojo::Exception')){
                    return $self->render(json=>{exception=>{message=>$err->message,code=>9999}});
                }
            }
            return $self->render(json=>{exception=>{
                message=>$err,code=>9999}});
        });
        $self->render_later;
        return $map;
    }
    #warn Dumper $return;
    $self->res->headers->content_type($map->{type}.';name=' .$map->{filename});
    $self->res->headers->content_disposition('attachment;filename='.$map->{filename});
    $self->res->content->asset($map->{asset});
    $self->rendered(200);
}


1;
__END__

=head1 BUGS

The idea was to implement preDestoryActions via a DESTROY method, but
it seems that the datastructures in the controller are not letting it
DESTORY itself as the handle goes out of scope. For now I am using the
finish event on tx ... not pretty.

=head1 COPYRIGHT

Copyright (c) 2013 by OETIKER+PARTNER AG. All rights reserved.

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

 2013-01-01 to Initial

=cut

1;

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
