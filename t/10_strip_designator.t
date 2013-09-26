#!perl

use Test::More;
use Business::CompanyDesignator;
use Data::Dump qw(dd pp dump);

binmode(\*STDOUT, ':utf8');

my @testdata = (
  [ 'News Corporation'          => 'News',              'Corporation' ],
  [ 'Open Fusion Pty. Ltd.'     => 'Open Fusion',       'Pty. Ltd.' ],
);

my ($bcd, $data, $strip, $des);

ok($bcd = Business::CompanyDesignator->new, 'constructor ok');
ok($data = $bcd->data, 'data method ok');
#dd $data;
for my $t (@testdata) {
  # List context
  ($strip, $des) = $bcd->strip_designator($t->[0]);
  is($strip, $t->[1], "$t->[0]: stripped name ok");
  is($des,   $t->[2], "$t->[0]: designator ok");
}

done_testing;

