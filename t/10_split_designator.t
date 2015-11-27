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
  my ($company_name, $stripped_name, $designator, $designator_std, $after) = @$t;

  # Array-context split_designator
  my ($strip, $des, $trailing, $normalised_des) = $bcd->split_designator($company_name);

  is($strip, $stripped_name, "$company_name: stripped name ok: $strip");
  is($des,   $designator, "$company_name designator ok: " . ($des // 'undef'));
  is($normalised_des, $designator_std, "$company_name normalised_des ok: " . ($normalised_des // 'undef'));
  if ($after || $trailing) {
    is($trailing, $after, "$company_name trailing ok: " . ($trailing // 'undef'));
  }

  # Test that $normalised_des maps back to one or more records
  if ($normalised_des) {
    my @records = $bcd->records($normalised_des);
    ok(scalar @records, 'records returned ' . scalar(@records) . ' record(s): '
      . join(',', map { $_->long } @records));
  }

  # Scalar-context split_designator
  my $res = $bcd->split_designator($company_name);
  is($res->before, $stripped_name, "$company_name: before ok: " . $res->before);
  is($res->designator, $designator // '', "$company_name designator ok: " . ($res->designator // 'undef'));
  is($res->designator_std, $designator_std // '', "$company_name designator_std ok: " . ($res->designator_std // 'undef'));
  if ($res->after || $trailing) {
    is($res->after, $trailing, "$company_name after ok: " . ($res->after // 'undef'));
  }
}

for my $company_name (@bad) {
  my ($strip, $des, $after, $normalised_des) = $bcd->split_designator($company_name);
  is($strip, $company_name, "non-matching $company_name: stripped name is company name");
  is($des, undef, "non-matching $company_name: designator undef");
  is($normalised_des, undef, "non-matching $company_name: normalised_des undef");
}

done_testing;

