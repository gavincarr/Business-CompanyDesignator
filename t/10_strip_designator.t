#!perl

use 5.010;
use strict;
use Test::More;
use Business::CompanyDesignator;
use Data::Dump qw(dd pp dump);

binmode(\*STDOUT, ':utf8');

my @testdata = (
  [ 'News Corporation'          => 'News',                      'Corporation',  'Corporation' ],
  [ 'Open Fusion Pty Ltd.'      => 'Open Fusion',               'Pty Ltd.',     'Pty. Ltd.' ],
  # Check we are only matching literal dots
  [ 'Open Fusion Pty1 Ltd2'     => 'Open Fusion Pty1 Ltd2',     undef,          undef  ],
);

my ($bcd, $data, $strip, $des, $match);

ok($bcd = Business::CompanyDesignator->new, 'constructor ok');
ok($data = $bcd->data, 'data method ok');
#dd $data;
#say $bcd->designator_regex;
for my $t (@testdata) {
  my ($company_name, $stripped_name, $designator, $matching) = @$t;

  # List context
  ($strip, $des, $match) = $bcd->strip_designator($company_name);

  is($strip, $stripped_name, "$company_name: stripped name ok: $strip");
  is($des,   $designator, "$company_name designator ok: " . ($des // 'undef'));
  is($match, $matching, "$company_name match ok: " . ($match // 'undef'));
}

done_testing;

