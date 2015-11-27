package Business::CompanyDesignator::SplitResult;

use Mouse;
use utf8;
use warnings qw(FATAL utf8);
use Carp;
use namespace::autoclean;

has [ qw(before after designator designator_std) ] =>
  ( is => 'ro', isa => 'Str', required => 1 );
has 'records' => ( is => 'ro', isa => 'ArrayRef', required => 1 );

sub short_name {
  my $self = shift;
  $self->before || $self->after;
}

sub extra {
  my $self = shift;
  $self->before ? $self->after : '';
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Business::CompanyDesignator::SplitResult - class for modelling
L<Business::CompanyDesignator::split_designator> result records

=head1 SYNOPSIS

  # Returned by split_designator in scalar context
  $bcd = Business::CompanyDesignator->new;
  $res = $bcd->split_designator("Open Fusion Pty Ltd (Australia)");

  # Accessors
  say $res->before;             # Open Fusion (trimmed text before designator)
  say $res->after;              # (Australia) (trimmed text after designator)
  say $res->short_name;         # Open Fusion ($res->before || $res->after)
  say $res->extra;              # (Australia) ($res->before ? $res->after : '')
  say $res->designator;         # Pty Ltd (designator as found in input string)
  say $res->designator_std;     # Pty. Ltd. (standardised version of designator)

  # Designator records arrayref (since designator might be ambiguous and map to multiple)
  foreach (@{ $res->records }) {
    say join ", ", $_->long, $_->lang;
  }


=head1 ACCESSORS

=head2 before()

Returns the record's long designator (a string).

  $long = $record->long;

=head2 designator()

Returns a list of the abbreviations associated with this record (if any).

  @abbr = $record->abbr;

=head2 designator_std()

Returns the first abbreviation associated with this record (a string, if any).

  $abbr1 = $record->abbr1;

=head2 after()

Returns the ISO-639 language code associated with this record (a string).

  $lang = $record->lang;

=head1 AUTHOR

Gavin Carr <gavin@profound.net>

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2013-2015 Gavin Carr

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

