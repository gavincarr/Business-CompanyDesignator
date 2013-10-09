package Business::CompanyDesignator;

# Require perl 5.010 because the 'track' functionality of Regexp::Assemble
# is unsafe for earlier versions.
use 5.010;
use Mouse;
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
sub add_to_assembler {
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
    $self->add_to_assembler($stripped, $string);
  }
}

# Assemble designator regex
sub _build_regex {
  my $self = shift;

  while (my ($long, $entry) = each %{ $self->data }) {
    $long = NFD $long;
    $self->add_to_assembler($long);

    # Add all abbreviations
    if (my $abbr_list = $entry->{abbr}) {
      $abbr_list = [ $abbr_list ] if ! ref $abbr_list;
      for my $abbr (@$abbr_list) {
        $abbr = NFD($abbr);
        $self->add_to_assembler($abbr);
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
# e.g. matching "ABC Pty" Ltd would return "Pty Ltd" for $designator, but "Pty. Ltd." for
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

=head1 SYNOPSIS

  use Business::CompanyDesignator;
  
  # Constructor
  $bcd = Business::CompanyDesignator->new;
  # Optionally, you can provide your own company_designator.yml file, instead of the bundled one
  $bcd = Business::CompanyDesignator->new(datafile => '/path/to/company_designator.yml');

  # Accessors
  # Get lists of designators, which may be long (e.g. Limited) or abbreviations (e.g. Ltd.)
  @des = $bcd->designators;
  @long = $bcd->long_designators;
  @abbrev = $bcd->abbreviations;

  # Get a regex for matching designators
  $re = $bcd->regex;
  $company_name =~ $re and say 'designator found!';
  $company_name =~ /$re\s*$/ and say 'final designator found!';

  # Methods
  # Split $company_name on designator, returning a ($before, $designator, $after) triplet,
  # plus the normalised form of the designator matched
  ($short_name, $des, $after, $normalised_des) = $bcd->split_designator($company_name);

  # Access designator records (returns Business::CompanyDesignator::Record objects)
  # Lookup record by long designator (unique)
  $record = $bcd->record($long_designator);
  # Lookup records by abbreviation or long designator (may not be unique)
  @records = $bcd->records($designator);


=head1 DESCRIPTION

Business::CompanyDesignator is a perl module for matching and manipulating
the typical company designators appended to company names. It supports both
long forms (e.g. Corporation, Incorporated, Limited etc.) and abbreviations
(e.g. Corp., Inc., Ltd., GmbH etc).

Business::CompanyDesignator uses the company designator dataset from here:

which is bundled with the module. You can use your own (updated or custom)
version if you prefer, by passing a 'datafile' parameter to the constructor.

=head1 AUTHOR

Gavin Carr <gavin@profound.net>

=head1 COPYRIGHT AND LICENCE

Copyright (C) Gavin Carr and Profound Networks 2013.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.10.0 or, at
your option, any later version of Perl 5.

=cut

