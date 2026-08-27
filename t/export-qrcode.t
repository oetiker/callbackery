use FindBin;

use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';

use Mojo::Base -strict;

use Test::More;
use Test::Fatal qw(exception);
use Compress::Zlib qw(uncompress);

use CallBackery::GuiPlugin::AbstractTable;
use CallBackery::Translate qw(trm);

my $C = 'CallBackery::GuiPlugin::AbstractTable';

package TestTable;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);

has app => sub { TestApp->new };
has user => sub { TestUser->new };

sub tableCfg ($self) {
    return [
        { key => 'id',     label => trm('Id'),     type => 'number' },
        { key => 'serial', label => trm('Serial'), type => 'str'    },
        { key => 'note',   label => trm('Note'),   type => 'str'    },
    ];
}

sub getTableRowCount ($self, $args) { return 3 }

sub getTableData ($self, $args) {
    return [
        { id => 1, serial => 'AAA', note => 'first'  },
        { id => 2, serial => 'BBB', note => 'second' },
        { id => 3, serial => 'AAA', note => 'third'  },
    ];
}

package TestApp;
use Mojo::Base -base, -signatures;
use Mojo::Home;
use FindBin;
has home => sub { Mojo::Home->new($FindBin::Bin.'/..') };

package TestUser;
use Mojo::Base -base, -signatures;
has userInfo => sub { { lang => 'en' } };

package main;

# --- column plan ------------------------------------------------------

my $tCfg = [
    { key => 'id',     label => 'Id'     },
    { key => 'serial', label => 'Serial' },
    { key => 'note',   label => 'Note'   },
];

is_deeply(
    [ map { $_->{extra} ? 'X:'.$_->{extra}{content} : $_->{col}{key} }
        @{ $C->_exportColumnPlan($tCfg, undef) } ],
    [ qw(id serial note) ],
    'no extraCols leaves the plan untouched'
);

is_deeply(
    [ map { $_->{extra} ? 'X:'.$_->{extra}{content} : $_->{col}{key} }
        @{ $C->_exportColumnPlan($tCfg,
            [ { type => 'qrCode', content => 'serial' } ]) } ],
    [ qw(id serial X:serial note) ],
    'without insertAfter the extra column follows its source column'
);

is_deeply(
    [ map { $_->{extra} ? 'X:'.$_->{extra}{content} : $_->{col}{key} }
        @{ $C->_exportColumnPlan($tCfg,
            [ { type => 'qrCode', content => 'serial', insertAfter => 0 } ]) } ],
    [ qw(id X:serial serial note) ],
    'insertAfter overrides the default placement'
);

# both indices refer to the ORIGINAL tableCfg, so the inserts cannot shift
# each other around
is_deeply(
    [ map { $_->{extra} ? 'X:'.$_->{extra}{content} : $_->{col}{key} }
        @{ $C->_exportColumnPlan($tCfg, [
            { type => 'qrCode', content => 'id',     insertAfter => 0 },
            { type => 'qrCode', content => 'serial', insertAfter => 1 },
        ]) } ],
    [ qw(id X:id serial X:serial note) ],
    'several extra columns all resolve against the original indices'
);

is(
    $C->_exportColumnPlan($tCfg,
        [ { type => 'qrCode', content => 'serial' } ])->[2]{extra}{label},
    undef,
    'label stays undefined when not given'
);

like(
    exception { $C->_exportColumnPlan($tCfg,
        [ { type => 'qrCode', content => 'nosuch' } ]) },
    qr{nosuch},
    'an unknown content key is refused'
);

like(
    exception { $C->_exportColumnPlan($tCfg,
        [ { type => 'qrCode', content => sub { 'x' } } ]) },
    qr{insertAfter},
    'a coderef content needs an explicit insertAfter'
);

like(
    exception { $C->_exportColumnPlan($tCfg,
        [ { type => 'barCode', content => 'serial' } ]) },
    qr{barCode},
    'an unknown extra column type is refused'
);

like(
    exception { $C->_exportColumnPlan($tCfg,
        [ { type => 'qrCode', content => 'serial', insertAfter => 9 } ]) },
    qr{insertAfter},
    'an out of range insertAfter is refused'
);

# --- png writer -------------------------------------------------------

# 3x3 matrix: dark on the diagonal
my $matrix = [
    [ '*', ' ', ' ' ],
    [ ' ', '*', ' ' ],
    [ ' ', ' ', '*' ],
];

my $png = $C->_qrPng($matrix, 2, 1);   # 2px per module, 1 module quiet zone
my $side = (3 + 2 * 1) * 2;            # 10 pixels

is(substr($png, 0, 8), "\x89PNG\r\n\x1a\n", 'starts with the png signature');

my %chunk;
my @order;
my $pos = 8;
while ($pos < length $png) {
    my ($len, $type) = unpack 'N a4', substr($png, $pos, 8);
    my $data = substr($png, $pos + 8, $len);
    my $crc  = unpack 'N', substr($png, $pos + 8 + $len, 4);
    is($crc, Compress::Zlib::crc32($type.$data), "$type chunk crc is correct");
    $chunk{$type} = $data;
    push @order, $type;
    $pos += 12 + $len;
}

is_deeply(\@order, [qw(IHDR IDAT IEND)], 'has exactly the chunks we write');
is($pos, length($png), 'no trailing garbage');

my ($w, $h, $depth, $colour, $comp, $filter, $interlace)
    = unpack 'N N C C C C C', $chunk{IHDR};
is($w, $side, 'image width covers the modules and the quiet zone');
is($h, $side, 'image height covers the modules and the quiet zone');
is($depth, 1, '1 bit per pixel');
is($colour, 0, 'greyscale');
is($comp, 0, 'deflate');
is($filter, 0, 'default filtering');
is($interlace, 0, 'not interlaced');

my $raw = uncompress($chunk{IDAT});
my $stride = 1 + int(($side + 7) / 8);       # filter byte + packed bits
is(length($raw), $stride * $side, 'one filtered scanline per pixel row');

# rebuild the pixels: 0 is dark, 1 is light
my @pixel;
for my $y (0 .. $side - 1) {
    my $line = substr($raw, $y * $stride, $stride);
    is(ord(substr($line, 0, 1)), 0, "scanline $y uses filter type 0")
        if $y < 2;
    my $bits = unpack 'B*', substr($line, 1);
    push @pixel, [ split //, substr($bits, 0, $side) ];
}

is($pixel[0][0], '1', 'the quiet zone is light');
is($pixel[$side-1][$side-1], '1', 'the quiet zone is light on the far corner');
is($pixel[2][2], '0', 'the first dark module is dark');
is($pixel[3][3], '0', 'and covers moduleSize pixels');
is($pixel[2][4], '1', 'the module beside it is light');
is($pixel[4][4], '0', 'the second diagonal module is dark');
is($pixel[6][6], '0', 'the third diagonal module is dark');

# --- against a real qr code -------------------------------------------

SKIP: {
    eval { require Text::QRCode; 1 }
        or skip 'Text::QRCode is not installed', 3;
    my $m = Text::QRCode->new->plot('CallBackery');
    is(scalar @$m, scalar @{$m->[0]}, 'the qr matrix is square');
    my $real = $C->_qrPng($m, 4);
    is(substr($real, 0, 8), "\x89PNG\r\n\x1a\n", 'a real qr code renders to png');
    my ($rw) = unpack 'N', substr($real, 16, 4);
    is($rw, (scalar(@$m) + 8) * 4, 'default quiet zone is 4 modules wide');
}

# --- end to end xlsx ---------------------------------------------------

SKIP: {
    eval { require Text::QRCode; 1 }
        or skip 'Text::QRCode is not installed', 7;

    # count how often a qr code is actually rendered, so the cache is
    # tested rather than Excel::Writer::XLSX's own file deduplication
    my $renders = 0;
    my $render = \&CallBackery::GuiPlugin::AbstractTable::_qrPng;
    no warnings 'redefine';
    local *CallBackery::GuiPlugin::AbstractTable::_qrPng
        = sub { $renders++; goto $render };
    use warnings 'redefine';

    my $plugin = TestTable->new;
    my $action = $plugin->makeExportAction(
        type      => 'XLSX',
        extraCols => [
            { type => 'qrCode', content => 'serial' },
            { type => 'qrCode', content => sub { 'X'.shift->{id} },
              insertAfter => 2, label => 'Tag', size => 60 },
        ],
    );
    my $out = $action->{actionHandler}->($plugin, {});
    is($out->{type},
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'the export is still an xlsx');

    my $xlsx = $out->{asset}->slurp;
    is(substr($xlsx, 0, 2), 'PK', 'the workbook is a zip');

    # the sheet xml and the embedded png both live in the zip; grep the
    # central directory for their names rather than unpacking it
    like($xlsx, qr{xl/media/image1\.png}, 'a png was embedded');
    like($xlsx, qr{xl/drawings/drawing1\.xml}, 'and anchored by a drawing');

    # 6 qr cells are drawn (3 serials + 3 tags) but only 5 distinct strings
    # exist, because two records share the serial 'AAA'
    is($renders, 5, 'identical content is only rendered once');
    my @png = $xlsx =~ m{xl/media/image(\d+)\.png}g;
    my %seen; $seen{$_}++ for @png;
    is(scalar keys %seen, 5, 'and each rendering is embedded once');

    # header row: id | serial | QR | note | Tag
    my $csvAction = $plugin->makeExportAction(
        type      => 'CSV',
        extraCols => [ { type => 'qrCode', content => 'serial' } ],
    );
    my $csv = $csvAction->{actionHandler}->($plugin, {})->{asset}->slurp;
    like($csv, qr{^"?Id"?,"?Serial"?,"?Note"?\r?$}m,
        'csv ignores the extra columns');
}

SKIP: {
    eval { require Text::QRCode; 1 }
        or skip 'Text::QRCode is not installed', 1;

    # more than a qr code can hold must not escape as a raw XS error
    my $plugin = TestTable->new;
    my $action = $plugin->makeExportAction(
        type      => 'XLSX',
        extraCols => [ { type => 'qrCode', insertAfter => 0,
                         content => sub { 'x' x 5000 } } ],
    );
    like(
        exception { $action->{actionHandler}->($plugin, {}) },
        qr{QR code},
        'content too large for a qr code gives a readable error'
    );
}

done_testing;
