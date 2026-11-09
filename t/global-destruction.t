use FindBin;

use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';
use lib $FindBin::Bin.'/lib';

use Mojo::Base -strict;

use Test::More;
use Mojo::File qw(path tempfile);
use CallBackeryTest qw(setupTestConfig);

# Objects still alive when a worker exits are destroyed in global
# destruction. Their DESTROY must not touch the (already torn down) app,
# log or helpers: that printed "Use of uninitialized value" and
# "Can't locate object method" lines on every worker exit.

setupTestConfig();

my $child = <<'CHILD';
use Mojo::Base -strict;
use CallBackery;
use CallBackery::User;
use CallBackery::Controller::RpcService;
use CallBackery::GuiPlugin::Abstract;

our @keep;
my $app = CallBackery->new;
push @keep, $app;
push @keep, CallBackery::Controller::RpcService->new(app => $app);
push @keep, CallBackery::User->new(app => $app);
push @keep, CallBackery::GuiPlugin::Abstract->new(app => $app, user => $keep[-1]);
# a cycle keeps the controller alive until global destruction
$keep[1]{self} = $keep[1];
CHILD

my $script = tempfile(SUFFIX => '.pl');
$script->spew($child);
my $err = tempfile(SUFFIX => '.err');

my @inc = map { ('-I', $_) } "$FindBin::Bin/../lib", "$FindBin::Bin/../thirdparty/lib/perl5";
system("$^X @inc $script 2>$err");
is $? >> 8, 0, 'child exits cleanly';

my $out = $err->slurp;
unlike $out, qr/uninitialized/, 'no uninitialized value warnings';
unlike $out, qr/Can't locate object method/, 'no missing method errors';
unlike $out, qr/\(in cleanup\)/, 'no errors in cleanup';
unlike $out, qr/extra late destruction/, 'no "extra late" variant';
like $out, qr/^late destruction of \S+ object during global destruction$/m,
    'late destruction is reported with a plain warning'
    or diag $out;
my @late = $out =~ /^(late destruction of .*)$/mg;
my %seen; $seen{$_}++ for @late;
ok !(grep { $_ > 1 } values %seen), 'each object is reported once'
    or diag $out;

done_testing;
