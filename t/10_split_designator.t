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

my ($bcd, $data, $records);

ok($bcd = Business::CompanyDesignator->new, 'constructor ok');
ok($data = $bcd->data, 'data method ok');

for my $t (@$good) {
  my ($company_name, $exp_short_name, $exp_des, $exp_des_std, $exp_extra) = @$t;

  # Array-context split_designator
  my ($short_name, $des, $extra, $normalised_des) = $bcd->split_designator($company_name);

  is($short_name, $exp_short_name, "$company_name: stripped name ok: $short_name");
  is($des, $exp_des, "$company_name designator ok: " . ($des // 'undef'));
  is($normalised_des, $exp_des_std, "$company_name normalised_des ok: " . ($normalised_des // 'undef'));
  if ($exp_extra || $extra) {
    is($extra, $exp_extra, "$company_name trailing ok: " . ($extra // 'undef'));
  }

  # Test that $normalised_des maps back to one or more records
  if ($normalised_des) {
    my @records = $bcd->records($normalised_des);
    ok(scalar @records, 'records returned ' . scalar(@records) . ' record(s): '
      . join(',', map { $_->long } @records));
  }

  # Scalar-context split_designator
  my $res = $bcd->split_designator($company_name);
  is($res->short_name, $exp_short_name, "$company_name: before ok: " . $res->before);
  is($res->designator, $exp_des // '', "$company_name designator ok: " . ($res->designator // 'undef'));
  is($res->designator_std, $exp_des_std // '', "$company_name designator_std ok: " . ($res->designator_std // 'undef'));
  if ($res->extra || $extra) {
    is($res->extra, $extra, "$company_name extra ok: " . ($res->extra // 'undef'));
  }
  if ($res->designator_std) {
    ok($records = $res->records, "$company_name result object includes records: " . scalar(@$records));
    ok($records->[0]->long, 'record 0 long exists: ' . $records->[0]->long);
    ok($records->[0]->lang, 'record 0 lang exists: ' . $records->[0]->lang);
  }
}

for my $company_name (@bad) {
  my ($short_name, $des, $after, $normalised_des) = $bcd->split_designator($company_name);
  is($short_name, $company_name, "non-matching $company_name: stripped name is company name");
  is($des, undef, "non-matching $company_name: designator undef");
  is($normalised_des, undef, "non-matching $company_name: normalised_des undef");
}

done_testing;

