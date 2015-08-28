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
    'Mojolicious' => '6.17',
    'Mojolicious::Plugin::Qooxdoo' => '0.904',
    'Locale::PO' => '0.24',
    'Config::Grammar' => '1.10',
    'Mojo::SQLite' => '0.011',
    'PPI' => '0',
  },
  META_MERGE   => {
    requires  => {perl => '5.010001'},
    resources => {
      license     => 'http://opensource.org/licenses/GPL-3.0',
      repository  => 'https://github.com/oetiker/callbackery',
      bugtracker  => 'https://github.com/oetiker/callbackery/issues'
    },
    no_index => {directory => ['t','example','setup','lib/Mojolicious/Command/generate/callbackery_app']}
  },
  test => {TESTS => 't/*.t'}
);
