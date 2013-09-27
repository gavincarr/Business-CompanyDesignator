#!perl

use 5.010;
use strict;
use utf8;
use open qw(:std :utf8);
use Test::More;
use Business::CompanyDesignator;
use Data::Dump qw(dd pp dump);

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
  [ 'Gruppo Formula SpA'        => 'Gruppo Formula',            'SpA',          'S.p.A.' ],
  [ 'Gruppo Formula SPA'        => 'Gruppo Formula',            'SPA',          'S.p.A.' ],
  [ 'MySQL AB'                  => 'MySQL',                     'AB',           'AB' ],
  [ 'A Schulman Plastics SL'    => 'A Schulman Plastics',       'SL',           'S.L.' ],
  [ 'Stølen Mat AS'             => 'Stølen Mat',                'AS',           'AS' ],
  [ 'Mec Denmark A/S'           => 'Mec Denmark',               'A/S',          'A/S' ],
  [ 'Mec Denmark AS'            => 'Mec Denmark',               'AS',           'AS' ],
  [ 'Sheng Siong Supermarket Pte Ltd' => 'Sheng Siong Supermarket', 'Pte Ltd', 'Pte. Ltd.' ],
  [ 'Kernkraftwerk Brokdorf GmbH & Co OHG' => 'Kernkraftwerk Brokdorf', 'GmbH & Co OHG', 'GmbH & Co OHG' ],
  [ 'Iberese Sociedad Anónima'  => 'Iberese',                   'Sociedad Anónima', 'Sociedad Anónima' ],
  [ 'Iberese Sociedad Anonima'  => 'Iberese',                   'Sociedad Anonima', 'Sociedad Anónima' ],
  [ 'Zukunftsbaugesellschaft MBH' => 'Zukunftsbaugesellschaft', 'MBH',          'mbH' ],
  [ 'Accessoires Pour Velos O G D Ltée', 'Accessoires Pour Velos O G D', 'Ltée', 'Ltée' ],
  [ 'Woon-En Zorgcentrum Onze-Lieve-Vrouw Van Antwerpen Verkort Olva VZW' =>
       'Woon-En Zorgcentrum Onze-Lieve-Vrouw Van Antwerpen Verkort Olva', 'VZW', 'VZW' ],
# [ 'Verein Fuer Jugendfuersorge und Jugendpflege E. V.' =>
#      'Verein Fuer Jugendfuersorge und Jugendpflege', 'E. V.', 'e.V.' ],
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

