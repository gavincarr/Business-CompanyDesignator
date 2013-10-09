#!perl

# Test B::CD abbreviation_records() method

use 5.010;
use strict;
use utf8;
use open qw(:std :utf8);
use Test::More;
use Test::Exception;
use Business::CompanyDesignator;
use Data::Dump qw(dd pp dump);

my ($bcd, @abbrev, @records);

ok($bcd = Business::CompanyDesignator->new, 'constructor ok');
ok(@abbrev = $bcd->abbreviations, 'abbreviations method ok, found ' . scalar(@abbrev));
for my $abbrev (@abbrev) {
  ok(@records = $bcd->abbreviation_records($abbrev), "records found for abbrev '$abbrev': " . scalar(@records));
  for my $record (@records) {
    ok(ref $record && $record->isa('Business::CompanyDesignator::Record'),
      'record isa Business::CompanyDesignator::Record');
    my $long = $record->long;
    ok($long && ! ref $long, "long is string: " . $long);
    my $abbr = $record->abbr;
    ok($abbrev ~~ @$abbr, "abbrev $abbrev included in '$long' abbreviations");
    my $abbr1 = $record->abbr1;
    ok(! defined $abbr1 || ! ref $abbr1, "abbr1 is string (or undef): " . $abbr1||'undef');
    my $lang = $record->lang;
    ok($lang && ! ref $lang, "lang is string: " . $lang);
  }
}

dies_ok { $bcd->abbreviation_records('Bogus') } 'abbreviation_records() dies on bogus abbrev';

done_testing;

