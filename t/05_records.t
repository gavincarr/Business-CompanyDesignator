#!perl

# Test B::CD records() method

use 5.010;
use strict;
use utf8;
use open qw(:std :utf8);
use Test::More;
use Test::Exception;
use Business::CompanyDesignator;
use Data::Dump qw(dd pp dump);

my ($bcd, @long, $record);

ok($bcd = Business::CompanyDesignator->new, 'constructor ok');
ok(@long = $bcd->long_designators, 'long_designators method ok, found ' . scalar(@long));
for my $long (@long) {
  ok($record = $bcd->record($long), "record found for long '$long'");
  ok(ref $record && $record->isa('Business::CompanyDesignator::Record'), 'record isa Business::CompanyDesignator::Record');
  is($record->long, $long, "\$record->long is '$long'");
  my $abbr = $record->abbr;
  ok(! defined $abbr || ref $abbr eq 'ARRAY', "abbr is arrayref (or undef): " . (defined $abbr ? @$abbr : 'undef'));
  my $abbr1 = $record->abbr1;
  ok(! defined $abbr1 || ! ref $abbr1, "abbr1 is string (or undef): " . $abbr1||'undef');
  my $lang = $record->lang;
  ok($lang && ! ref $lang, "lang is string: " . $lang);
}

dies_ok { $bcd->record('Bogus') } 'record() dies on bogus long';

done_testing;

