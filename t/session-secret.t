use FindBin;

use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';
use lib $FindBin::Bin.'/lib';

use Mojo::Base -strict;

use Test::More;
use CallBackery::Config;
use File::Temp qw(tempdir);
use Mojo::File qw(path);

my $dir = tempdir(CLEANUP => 1);
my @secret = map {
    srand(42);
    path(CallBackery::Config->new(file => "$dir/$_.cfg")->secretFile)->slurp;
} 1, 2;

isnt $secret[0], $secret[1], 'the session secret does not follow from the srand seed';
like $secret[0], qr/^[0-9a-f]{64}$/, 'the session secret is 32 random bytes in hex';

path("$dir/old.cfg.secret")->spew('5af3e1b2c4d9e8f7a6b5c4d3');
path("$dir/empty.cfg.secret")->spew('');
like path(CallBackery::Config->new(file => "$dir/$_.cfg")->secretFile)->slurp, qr/^[0-9a-f]{64}$/,
    "a secret file that is $_ is replaced" for qw(old empty);

done_testing();
