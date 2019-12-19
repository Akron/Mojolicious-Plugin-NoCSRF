#!/usr/bin/env perl
use 5.010001;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::NoCSRF',
  AUTHOR       => 'Nils Diewald',
  ABSTRACT     => 'Defend Cross-Site-Request-Forgery Attacks with Control',
  VERSION_FROM => 'lib/Mojolicious/Plugin/NoCSRF.pm',
  BUILD_REQUIRES => {
    'Test::More' => 0
  },
  PREREQ_PM => {
    'Mojolicious' => 8.02,
    'Mojolicious::Plugin::Localize' => 0.20,
    'Mojolicious::Plugin::Util::RandomString' => 0.08
  },
  META_MERGE   => {
    requires  => { perl => '5.010001' },
    resources => {
      license     => 'http://www.opensource.org/licenses/artistic-license-2.0',
      repository  => 'https://github.com/Akron/Mojolicious-Plugin-NoCSRF'
    }
  },
  MIN_PERL_VERSION => '5.010001',
  test => {TESTS => 't/*.t'}
);

