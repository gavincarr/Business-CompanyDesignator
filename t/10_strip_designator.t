#!perl

use 5.010;
use strict;
use utf8;
use open qw(:std :utf8);
use Test::More;
use Business::CompanyDesignator;
use Data::Dump qw(dd pp dump);

# Data format: company_name, stripped_name, designator (stripped), designator (matched), after
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
  [ 'Zukunftsbaugesellschaft MBH' => 'Zukunftsbaugesellschaft', 'MBH',          'mbH' ],
  [ 'Accessoires Pour Velos O G D Ltée', 'Accessoires Pour Velos O G D', 'Ltée', 'Ltée' ],
  [ 'Woon-En Zorgcentrum Onze-Lieve-Vrouw Van Antwerpen Verkort Olva VZW' =>
       'Woon-En Zorgcentrum Onze-Lieve-Vrouw Van Antwerpen Verkort Olva', 'VZW', 'VZW' ],
  # Handle misspellings that are due to missing unicode diacritics
  [ 'Iberese Sociedad Anónima'  => 'Iberese',                   'Sociedad Anónima', 'Sociedad Anónima' ],
  [ 'Iberese Sociedad Anonima'  => 'Iberese',                   'Sociedad Anonima', 'Sociedad Anónima' ],
  # Handle random spaces between designator elements
  [ 'Verein Fuer Jugendfuersorge und Jugendpflege E. V.' =>
       'Verein Fuer Jugendfuersorge und Jugendpflege', 'E. V.', 'e.V.' ],
  [ 'IT Solution Services Company Ltd' => 'IT Solution Services', 'Company Ltd', 'Company Ltd.' ],
  [ 'Amerihealth Insurance Company of NJ', 'Amerihealth Insurance', 'Company', 'Company', 'of NJ' ],
  [ 'True World Foods Inc of Hawaii', 'True World Foods', 'Inc', 'Inc.', 'of Hawaii' ],
  [ 'Trenkwalder Personal AG Schweiz', 'Trenkwalder Personal', 'AG', 'AG', 'Schweiz' ],
  [ 'Media Markt Tv-Hifi-Elektro GmbH Köln-Kalk', 'Media Markt Tv-Hifi-Elektro', 'GmbH', 'GmbH', 'Köln-Kalk' ],
);
my @bad = (
  # Check we are only matching literal dots
  'Open Fusion Pty1 Ltd2',
);

my ($bcd, $data);

ok($bcd = Business::CompanyDesignator->new, 'constructor ok');
ok($data = $bcd->data, 'data method ok');

for my $t (@good) {
  my ($company_name, $stripped_name, $designator, $matching, $after) = @$t;

  my ($strip, $des, $trailing, $match) = $bcd->split_designator($company_name);

  is($strip, $stripped_name, "$company_name: stripped name ok: $strip");
  is($des,   $designator, "$company_name designator ok: " . ($des // 'undef'));
  is($match, $matching, "$company_name match ok: " . ($match // 'undef'));
  if ($after || $trailing) {
    is($trailing, $after, "$company_name trailing ok: " . ($trailing // 'undef'));
  }
}

for my $company_name (@bad) {
  my ($strip, $des, $after, $match) = $bcd->split_designator($company_name);
  is($strip, $company_name, "non-matching $company_name: stripped name is company name");
  is($des, undef, "non-matching $company_name: designator undef");
  is($match, undef, "non-matching $company_name: match undef");
}

done_testing;

