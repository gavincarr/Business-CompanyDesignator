#!perl

use 5.010;
use strict;
use Test::More;
use Business::CompanyDesignator;
use Data::Dump qw(dd pp dump);

binmode(\*STDOUT, ':utf8');

# Data format: company_name, stripped_name, designator (stripped), designator (matched)
my @good = (
  # Check stripped vs. matched designators
  [ 'Open Fusion Pty Ltd'       => 'Open Fusion',               'Pty Ltd',      'Pty. Ltd.' ],
  # General tests
  [ 'News Corporation'          => 'News',                      'Corporation',  'Corporation' ],
  [ 'Wesfarmers Limited'        => 'Wesfarmers',                'Limited',      'Limited' ],
  [ 'Wesfarmers Ltd'            => 'Wesfarmers',                'Ltd',          'Ltd.' ],
  [ 'Gartner Inc. '             => 'Gartner',                   'Inc.',         'Inc.' ],
  [ 'Gartner Inc'               => 'Gartner',                   'Inc',          'Inc.' ],
  [ 'MySQL AB'                  => 'MySQL',                     'AB',           'AB' ],
);
my @bad = (
  # Check we are only matching literal dots
  'Open Fusion Pty1 Ltd2',
);

my ($bcd, $data, $strip, $des, $match);

ok($bcd = Business::CompanyDesignator->new, 'constructor ok');
ok($data = $bcd->data, 'data method ok');

for my $t (@good) {
  my ($company_name, $stripped_name, $designator, $matching) = @$t;

  # List context
  ($strip, $des, $match) = $bcd->strip_designator($company_name);

  is($strip, $stripped_name, "$company_name: stripped name ok: $strip");
  is($des,   $designator, "$company_name designator ok: " . ($des // 'undef'));
  is($match, $matching, "$company_name match ok: " . ($match // 'undef'));

  # Scalar context
  $strip = $bcd->strip_designator($company_name);
  is($strip, $stripped_name, "$company_name: scalar stripped name ok: $strip");
}

for my $company_name (@bad) {
  # List context
  ($strip, $des, $match) = $bcd->strip_designator($company_name);
  is($strip, $company_name, "non-matching $company_name: stripped name is company name");
  is($des, undef, "non-matching $company_name: designator undef");
  is($match, undef, "non-matching $company_name: match undef");

  # Scalar context
  $strip = $bcd->strip_designator($company_name);
  is($strip, $company_name, "non-matching $company_name: scalar stripped name is company name");
}

done_testing;

