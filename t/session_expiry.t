use FindBin;
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojo::Transaction::HTTP;

$ENV{CALLBACKERY_CONF} = $FindBin::Bin.'/callbackery.cfg';

my $t = Test::Mojo->new('CallBackery');

# --- Task 1: sessionExpired defaults to false and is settable ---
{
    my $tx = Mojo::Transaction::HTTP->new;
    $tx->req->method('POST');
    my $c = CallBackery::Controller::RpcService->new(tx => $tx, app => $t->app);
    my $u = CallBackery::User->new(app => $t->app, controller => $c);
    is($u->sessionExpired, 0, 'sessionExpired defaults to 0');
    $u->sessionExpired(1);
    is($u->sessionExpired, 1, 'sessionExpired is settable');
}

done_testing();
