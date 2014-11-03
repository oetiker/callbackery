use 5.010001;

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'CallBackery',
  VERSION_FROM => 'lib/CallBackery.pm',
  ABSTRACT     => 'CallBackery is a Mojolicious+Qoodoo Framework for building Web Applications',
  AUTHOR       => 'Tobias Oetiker <tobi@oetiker.ch>',
  LICENSE      => 'gpl_3',
  PREREQ_PM    => {
    'Mojolicious::Plugin::Qooxdoo' => '0.901',
    'Locale::PO' => '0.24',
    'Config::Grammar' => '1.10',
    'DBD::SQLite' => '1.40',
    'PPI' => '0'
  },
  META_MERGE   => {
    requires  => {perl => '5.010001'},
    resources => {
      license     => 'http://opensource.org/licenses/GPL-3.0',
      repository  => 'https://github.com/oetiker/callbackery',
      bugtracker  => 'https://github.com/oetiker/callbackery/issues'
    },
    no_index => {directory => ['t','example','setup']}
  },
  test => {TESTS => 't/*.t'}
);
