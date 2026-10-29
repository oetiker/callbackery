use FindBin;

use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';
use lib $FindBin::Bin.'/lib';

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use CallBackeryTest qw(setupTestConfig);
use File::Temp qw(tempdir);
use DBI;

setupTestConfig();

my $t = Test::Mojo->new('CallBackery');
my $cfg = $t->app->config;

require Archive::Zip;
my $dir = tempdir(CLEANUP => 1);
sub main::probe { open my $fh, '>', "$dir/tokenizer"; return sub {} }
for my $sql (".shell touch $dir/shell\n", "ATTACH DATABASE '$dir/attach' AS a;\nCREATE TABLE a.t (x);\n",
        "CREATE TABLE f AS SELECT data FROM fsdir('$FindBin::Bin/callbackery.cfg');\n",
        "PRAGMA writable_schema=ON;\n",
        "CREATE VIRTUAL TABLE v USING fts4(tokenize=perl 'main::probe');\nINSERT INTO v VALUES ('x');\n") {
    my $zip = Archive::Zip->new;
    $zip->addString("CREATE TABLE probe (x);\n$sql",'{DATABASEDUMP}');
    open my $fh, '>', \my $zipData;
    $zip->writeToFileHandle($fh,0);
    close $fh;
    my $blob = $cfg->getCrypt('secret')->encrypt($cfg->pack16($zipData));
    ok !eval { $cfg->restoreConfigBlob($blob,'secret'); 1 }, "a dump with '".($sql =~ s/\s.*//sr)."' is refused";
}
is_deeply [glob "$dir/*"], [], 'and it ran no command and created no file';

my $raw = tempdir(CLEANUP => 1).'/raw.db';
my $dbh = DBI->connect("dbi:SQLite:dbname=$raw",'','',{RaiseError => 1});
$dbh->do('CREATE VIRTUAL TABLE cbuser USING fts4(x)');
$dbh->do('PRAGMA writable_schema=ON');
$dbh->do(q{UPDATE sqlite_master SET sql = replace(sql,'CREATE VIRTUAL','CREATE  VIRTUAL') WHERE name = 'cbuser'});
$dbh->disconnect;
my $zip = Archive::Zip->new;
$zip->addFile({filename => $raw, zipName => '{DATABASE}'});
open my $fh, '>', \my $zipData;
$zip->writeToFileHandle($fh,0);
close $fh;
ok !eval { $cfg->restoreConfigBlob($cfg->getCrypt('secret')->encrypt($cfg->pack16($zipData)),'secret'); 1 },
    'a database file with a virtual table is refused';

done_testing();
