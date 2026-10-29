use FindBin;

use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';
use lib $FindBin::Bin.'/lib';

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use CallBackeryTest qw(setupTestConfig);
use Mojo::Util qw(hmac_sha1_sum);

setupTestConfig();

my $t = Test::Mojo->new('CallBackery');
my $db = $t->app->database;
my $long = 'p' x 100;
my $bob = $db->updateOrInsertData('cbuser',{login => 'bob', family => 'B', given => 'B', password => hmac_sha1_sum('bobpw')});
my $eve = $db->updateOrInsertData('cbuser',{login => 'eve', family => 'E', given => 'E', password => hmac_sha1_sum($long)});
my $login = sub { $t->app->userObject->new(app => $t->app)->login(@_) };

ok !$login->('bob','wrong'), 'a wrong password is refused';
ok $login->('bob','bobpw'), 'a user with an old password hash can log in';
like $db->fetchValue('cbuser',{id => $bob},'password'), qr/^\$bcrypt-sha256\$/, 'and the hash is replaced with a bcrypt hash';
ok $login->('bob','bobpw') && !$login->('bob','wrong'), 'the bcrypt hash checks the password';
ok $login->('eve',$long) && $login->('eve',$long), 'a password longer than 72 bytes still logs in after the upgrade';
ok !$login->('eve','p' x 99), 'and all of it counts';

my $checks = 0;
my $verify = \&Crypt::Passphrase::verify_password;
no warnings 'redefine';
local *Crypt::Passphrase::verify_password = sub { $checks++; goto &$verify };
my $legacy = $db->updateOrInsertData('cbuser',{login => 'old', family => 'O', given => 'O', password => hmac_sha1_sum('oldpw')});
is_deeply [map { $checks = 0; $login->(@$_); $checks } ['nobody','x'], ['bob',''], ['bob','wrong'], ['old','wrong']],
    [1,1,1,1], 'every failed login costs one bcrypt check, so its time does not tell whether the user exists';

done_testing();
