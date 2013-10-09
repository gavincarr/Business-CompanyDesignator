package Business::CompanyDesignator;

# Require perl 5.010 because the 'track' functionality of Regexp::Assemble
# is unsafe for earlier versions.
use 5.010;
use Mouse;
use utf8;
use warnings qw(FATAL utf8);
use FindBin qw($Bin);
use YAML;
use File::ShareDir qw(dist_file);
use List::MoreUtils qw(uniq);
use Regexp::Assemble;
use Unicode::Normalize;
use Carp;

use Business::CompanyDesignator::Record;

our $VERSION = '0.02';

has 'datafile' => ( is => 'ro', default => sub {
  # Development/test version
  my $local_datafile = "$Bin/../share/company_designator_dev.yml";
  return $local_datafile if -f $local_datafile;
  $local_datafile = "$Bin/../share/company_designator.yml";
  return $local_datafile if -f $local_datafile;
  # Installed version
  return dist_file('Business-CompanyDesignator', 'company_designator.yml');
});

has [ qw(data assembler regex) ] => ( is => 'ro', lazy_build => 1 );

# abbr_long_map is a hash mapping abbreviations (strings) back to an arrayref of
# long designators (since abbreviations are not necessarily unique)
has 'abbr_long_map' => ( is => 'ro', isa => 'HashRef', lazy_build => 1 );

# pattern_string_map is a hash mapping patterns back to their source string,
# since we do things like add additional patterns without diacritics
has 'pattern_string_map' => ( is => 'ro', isa => 'HashRef', default => sub { {} } );

sub _build_data {
  my $self = shift;
  YAML::LoadFile($self->datafile);
}

sub _build_assembler {
  my $self = shift;
  # RA constructor - case insensitive, with match tracking
  Regexp::Assemble->new->flags('i')->track(1);
}

sub _build_abbr_long_map {
  my $self = shift;
  my $map = {};
  while (my ($long, $entry) = each %{ $self->data }) {
    my $abbr_list = $entry->{abbr} or next;
    $abbr_list = [ $abbr_list ] if ! ref $abbr_list;
    for my $abbr (@$abbr_list) {
      $map->{$abbr} ||= [];
      push @{ $map->{$abbr} }, $long;
    }
  }
  return $map;
}

sub long_designators {
  my $self = shift;
  sort keys %{ $self->data };
}

sub abbreviations {
  my $self = shift;
  sort keys %{ $self->abbr_long_map };
}

sub designators {
  my $self = shift;
  sort $self->long_designators, $self->abbreviations;
}

# Return the B::CD::Record for $long designator
sub record {
  my ($self, $long) = @_;
  my $entry = $self->data->{$long}
    or croak "Invalid long designator '$long'";
  return Business::CompanyDesignator::Record->new( long => $long, record => $entry );
}

# Return a list of B::CD::Records for $designator
sub records {
  my ($self, $designator) = @_;
  if (exists $self->data->{$designator}) {
    return ( $self->record($designator) );
  }
  elsif (my $long_set = $self->abbr_long_map->{$designator}) {
    return map { $self->record($_) } @$long_set
  }
  else {
    croak "Invalid designator '$designator'";
  }
}

# Add $string to regex assembler
sub _add_to_assembler {
  my ($self, $string, $reference_string) = @_;
  $reference_string ||= $string;

  # FIXME: RA->add() doesn't work here because of known quantifier-escaping bugs:
  # https://rt.cpan.org/Public/Bug/Display.html?id=50228
  # https://rt.cpan.org/Public/Bug/Display.html?id=74449
  # $self->assembler->add($string)
  # Workaround by lexing and using insert()
  my @pattern = map {
    # Periods are treated as optional literals, with optional trailing commas and/or whitespace
    /\./   ? '\\.?,?\\s*?' :
    # Escape other regex metacharacters
    /[()]/ ? "\\$_" : $_
  } split //, $string;
  $self->assembler->insert(@pattern);

  # Also add pattern => $string mapping to pattern_string_map
  $self->pattern_string_map->{ join '', @pattern } = $reference_string;

  # If $string contains unicode diacritics, also add a version without them for misspellings 
  if ($string =~ m/\pM/) {
    my $stripped = $string;
    $stripped =~ s/\pM//g;
    $self->_add_to_assembler($stripped, $string);
  }
}

# Assemble designator regex
sub _build_regex {
  my $self = shift;

  while (my ($long, $entry) = each %{ $self->data }) {
    $long = NFD $long;
    $self->_add_to_assembler($long);

    # Add all abbreviations
    if (my $abbr_list = $entry->{abbr}) {
      $abbr_list = [ $abbr_list ] if ! ref $abbr_list;
      for my $abbr (@$abbr_list) {
        $abbr = NFD($abbr);
        $self->_add_to_assembler($abbr);
      }
    }
  }

  return $self->assembler->re;
}

# Helper to return split_designator results
sub _split_designator_result {
  my $self = shift;
  my ($before, $des, $after, $matched_pattern) = @_;
  my $matched_string = $self->pattern_string_map->{$matched_pattern}
    or die "Cannot find matched pattern '$matched_pattern' in pattern_string_map";
  return map { defined $_ && ! ref $_ ? NFC($_) : $_ } ($before, $des, $after, $matched_string);
}

# Split $company_name on (the first) company designator, returning a triplet of strings:
# ($before, $designator, $after), plus the normalised form of the designator. If no
# designator is found, just returns ($company_name).
# e.g. matching "ABC Pty Ltd" would return "Pty Ltd" for $designator, but "Pty. Ltd." for
# the normalised form, and "Accessoires XYZ Ltee" would return "Ltee" for $designator,
# but "Ltée" for the normalised form
sub split_designator {
  my $self = shift;
  my $company_name = shift;
  my $company_name_match = NFD($company_name);

  my $re = $self->regex;

  # Designators are usually final, so try that first
  if ($company_name_match =~ m/(.*?)[[:punct:]]*\s+($re)\s*$/) {
    return $self->_split_designator_result($1, $2, undef, $self->assembler->source($^R));
  }
  # Not final - check for an embedded designator with trailing content
  elsif ($company_name_match =~ m/(.*?)[[:punct:]]*\s+($re)(?:\s+(.*?))?$/) {
    return $self->_split_designator_result($1, $2, $3, $self->assembler->source($^R));
  }
  # No match - return $company_name unchanged
  else {
    return ($company_name);
  }
}

1;

__END__

=head1 NAME

Business::CompanyDesignator - module for matching and manipulating company designators appended to company names

=head1 VERSION

Version: 0.02.

This module is considered an B<ALPHA> release. Interfaces may change and/or break
without notice until the module reaches version 1.0.


=head1 SYNOPSIS

Business::CompanyDesignator is a perl module for matching and manipulating
the typical company designators appended to company names. It supports both
long forms (e.g. Corporation, Incorporated, Limited etc.) and abbreviations
(e.g. Corp., Inc., Ltd., GmbH etc).

  use Business::CompanyDesignator;
  
  # Constructor
  $bcd = Business::CompanyDesignator->new;
  # Optionally, you can provide your own company_designator.yml file, instead of the bundled one
  $bcd = Business::CompanyDesignator->new(datafile => '/path/to/company_designator.yml');

  # Get lists of designators, which may be long (e.g. Limited) or abbreviations (e.g. Ltd.)
  @des = $bcd->designators;
  @long = $bcd->long_designators;
  @abbrev = $bcd->abbreviations;

  # Lookup individual designator records (returns B::CD::Record objects)
  # Lookup record by long designator (unique)
  $record = $bcd->record($long_designator);
  # Lookup records by abbreviation or long designator (may not be unique)
  @records = $bcd->records($designator);

  # Get a regex for matching designators
  $re = $bcd->regex;
  $company_name =~ $re and say 'designator found!';
  $company_name =~ /$re\s*$/ and say 'final designator found!';

  # Split $company_name on designator, returning a ($before, $designator, $after) triplet,
  # plus the normalised form of the designator matched.
  ($short_name, $des, $after, $normalised_des) = $bcd->split_designator($company_name);


=head1 DATASET

Business::CompanyDesignator uses the company designator dataset from here:

  L<https://github.com/ProfoundNetworks/company_designator>

which is bundled with the module. You can use your own (updated or custom)
version, if you prefer, by passing a 'datafile' parameter to the constructor.

The dataset defines multiple long form designators (like "Company", "Limited",
or "Incorporée"), each of which have zero or more abbreviations (e.g. 'Co.',
'Ltd.', 'Inc.' etc.), and one or more language codes. The 'Company' entry,
for instance, looks like this:

  Company:
    abbr:
      - Co.
      - '& Co.'
      - and Co.
    lang: en

Long designators are unique across the dataset, but abbreviations are not
e.g. 'Inc.' is used for both "Incorporated" and "Incorporée".

=head1 METHODS

=head2 new()

Creates a Business::CompanyDesignator object.

  $bcd = Business::CompanyDesignator->new;

By default this uses the bundled company_designator dataset. You may
provide your own (updated or custom) version by passing via a 'datafile'
parameter to the constructor.

  $bcd = Business::CompanyDesignator->new(datafile => '/path/to/company_designator.yml');

=head2 designators()

Returns the full list of company designator strings from the dataset
(both long form and abbreviations).

  @designators = $bcd->designators;

=head2 long_designators()

Returns the full list of long form designators from the dataset.

  @long = $bcd->long_designators;

=head2 abbreviations()

Returns the full list of abbreviation designators from the dataset.

  @abbrev = $bcd->abbreviations;

=head2 record($long_designator)

Returns the Business::CompanyDesignator::Record object for the given
long designator (and dies if not found).

=head2 records($designator)

Returns a list of Business::CompanyDesignator::Record objects for the
given abbreviation or long designator (for long designators there will
only be a single record returned, but abbreviations may map to multiple
records).

Use this method for abbreviations, or if you're aren't sure of a
designator's type.

=head2 regex()

Returns a regex that matches all designators from the dataset
(case-insensitive, non-anchored).

=head2 split_designator($company_name)

Attempts to split $company_name on (the first) company designator found.
If found, it returns a list of four items - a triplet of strings from
$company_name: ( $before, $designator, $after ), plus a normalised version
of the designator as a fourth element.

  ($short_name, $des, $after_text, $normalised_des) = $bcd->split_designator($company_name);

The initial $des designator is the designator as matched in the text, while
the second $normalised_des is the normalised version as found in the dataset.
For instance, "ABC Pty Ltd" would return "Pty Ltd" as the $designator, but
"Pty. Ltd." as the normalised form, and the latter would be what you
would find in designators() or would lookup with records(). Similarly,
"Accessoires XYZ Ltee" (misspelt without the grave accent) would still be
matched, returning "Ltee" (as found) for the $designator, but "Ltée" as the
normalised form.

=head1 SEE ALSO

Finance::CompanyNames

=head1 AUTHOR

Gavin Carr <gavin@profound.net>

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2013 Gavin Carr and Profound Networks.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
