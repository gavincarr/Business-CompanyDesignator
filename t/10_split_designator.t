#!perl

use 5.010;
use strict;
use utf8;
use open qw(:std :utf8);
use Test::More;
use YAML qw(LoadFile);
use Data::Dump qw(dd pp dump);

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Business::CompanyDesignator;

my $good = LoadFile("$Bin/t10/good.yml");

my @bad = (
  # Check we are only matching literal periods, not any character
  'Open Fusion Pty1 Ltd2',
);

my ($bcd, $data);

ok($bcd = Business::CompanyDesignator->new, 'constructor ok');
ok($data = $bcd->data, 'data method ok');

for my $t (@$good) {
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

