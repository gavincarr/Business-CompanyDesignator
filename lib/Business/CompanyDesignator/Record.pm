package Business::CompanyDesignator::Record;

use Mouse;
use warnings qw(FATAL utf8);
use Carp;

has 'long'                  => ( is => 'ro', isa => 'Str', required => 1 );
has 'record'                => ( is => 'ro', isa => 'HashRef', required => 1 );

has [qw(abbr1 lang)]        => ( is => 'ro', lazy_build => 1 );
has 'abbr'                  => ( is => 'ro', isa => 'ArrayRef|Undef', lazy_build => 1 );

sub _build_abbr {
  my $self = shift;
  my $abbr = $self->record->{abbr} or return;
  return ref $abbr ? $abbr : [ $abbr ];
}

sub _build_abbr1 {
  my $self = shift;
  my $abbr = $self->abbr;
  if ($abbr && ref $abbr && @$abbr) {
    return $abbr->[0];
  }
}

sub _build_lang {
  my $self = shift;
  $self->record->{lang};
}

1;

