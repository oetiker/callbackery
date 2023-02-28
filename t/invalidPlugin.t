use FindBin;

use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

$ENV{CALLBACKERY_CONF} = $FindBin::Bin.'/callbackery.cfg';

my $t = Test::Mojo->new('CallBackery');

$t->post_ok('/QX-JSON-RPC' => json => {
    service => 'default',
    method=> 'processPluginData',
    id => 1,
    params => [
        "undefinedPlugin", {
            key      => 'randomKey',
            formData => {
            }
        },
        { qxLocale => 'de' }
    ]
})
    ->status_is(200, 'processPluginData of undefinedPlugin returns 200')
    ->json_is('' => {
        id => 1,
        error => {
            origin  => 2,
            code    => 9999,
            message => "Couldn't process request",
        }
    }, 'Got correct error handling from JsonRPcController');

done_testing;
exit;
