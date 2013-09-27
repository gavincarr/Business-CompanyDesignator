package Business::CompanyDesignator;

# Require perl 5.010 because the 'track' functionality of Regexp::Assemble
# is unsafe for earlier versions.
use 5.010;
use warnings qw(FATAL utf8);
use Mouse;
use FindBin qw($Bin);
use YAML;
use File::ShareDir qw(dist_file);
use List::MoreUtils qw(uniq);
use Regexp::Assemble;
use Unicode::Normalize;

our $VERSION = '0.01';

has 'datafile' => ( is => 'ro', default => sub {
  # Development/test version
  my $local_datafile = "$Bin/../share/company_designator_dev.yml";
  return $local_datafile if -f $local_datafile;
  $local_datafile = "$Bin/../share/company_designator.yml";
  return $local_datafile if -f $local_datafile;
  # Installed version
  return dist_file('Business-CompanyDesignator', 'company_designator.yml');
});

has [ qw(data assembler patterns regex) ]
  => ( is => 'ro', lazy_build => 1 );

has 'pattern_long_map'   => ( is => 'ro', isa => 'HashRef', default => sub { {} } );
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

sub long_designators {
  my $self = shift;
  sort keys %{ $self->data };
}

sub abbreviations {
  my $self = shift;
  my @abbreviations;
  for my $entry (values %{ $self->data }) {
    next if ! $entry->{abbr};
    push @abbreviations, ref $entry->{abbr} ? @{ $entry->{abbr} } : $entry->{abbr};
  }
  sort uniq @abbreviations;
}

sub designators {
  my $self = shift;
  sort $self->long_designators, $self->abbreviations;
}

# Convert a designator string into a pattern
sub _string_to_pattern {
  my ($self, $string) = @_;
  my $pattern = $string;

  # Treat all periods as optional, and allow random whitespace between elements
  $pattern =~ s/\./\\.?\\s*?/g;

  # Record mapping in pattern_string_map
  $self->pattern_string_map->{$pattern} = $string;

  return $pattern;
}

sub _add_to_pattern_long_map {
  my ($self, $pattern, $value) = @_;
  $self->pattern_long_map->{ $pattern } ||= [];
  push @{ $self->pattern_long_map->{ $pattern } }, $value;
}

# patterns is an ordered arrayref of patterns derived from designator strings
# Collating also builds a pattern_long_map of pattern => long_designator, and
# a pattern_string_map of pattern => source string
sub _build_patterns {
  my $self = shift;

  # Build patterns list and patterns map
  my (@pattern_long, @pattern_abbr);
  while (my ($long_designator, $entry) = each %{ $self->data }) {
    $long_designator = NFD($long_designator);
    # Add long_designator patterns
    push @pattern_long, $long_designator;
    my $pattern = $self->_string_to_pattern($long_designator);
#   push @pattern_long, $pattern;
    $self->_add_to_pattern_long_map($pattern => $long_designator);

    # Add all abbreviations
    if (my $abbr_list = $entry->{abbr}) {
      $abbr_list = [ $abbr_list ] if ! ref $abbr_list;
      for my $abbr (@$abbr_list) {
        $abbr = NFD($abbr);
        push @pattern_abbr, $abbr;
        $pattern = $self->_string_to_pattern($abbr);
#       push @pattern_abbr, $pattern;
        $self->_add_to_pattern_long_map($pattern => $long_designator);
      }
    }
  }

  # FIXME: do we need to sort these patterns??
  # sort({ length $a <=> length $b } @pattern_long)
  # sort({ length $a <=> length $b } @pattern_abbr)
  return [ @pattern_long, @pattern_abbr ];
}

# Assemble designator regex
sub _build_regex {
  my $self = shift;

  my @patterns = @{ $self->patterns };

  # FIXME: RA->add() doesn't work here because of known quantifier-escaping bugs:
  # https://rt.cpan.org/Public/Bug/Display.html?id=50228
  # https://rt.cpan.org/Public/Bug/Display.html?id=74449
  # $self->assembler->add(@patterns);
  # Workaround by lexing and using insert()
  for my $string (@patterns) {
    $self->assembler->insert(map { /\./ ? '\\.?\\s*?' : $_ } split //, $string);
    # Also add variants without unicode diacritics to catch misspellings
    if ($string =~ m/\pM/) {
      my $stripped_string = $string;
      $stripped_string =~ s/\pM//g;
      $self->assembler->insert(map { /\./ ? '\\.?\\s*?' : $_ } split //, $stripped_string);
      # Add stripped_string to pattern_string_map
      $self->pattern_string_map->{$stripped_string} ||= $self->pattern_string_map->{$string};
    }
  }

  return $self->assembler->re;
}

# Strip trailing designator from $company_name.
# In scalar context returns the stripped name; in list context returns
# a list containing ($stripped_name, $designator).
sub strip_designator {
  my $self = shift;
  my $company_name = shift;
  my $company_name_match = NFD($company_name);

  my $re = $self->regex;

  if ($company_name_match =~ m/(.*?)\s*($re)\s*$/) {
    my $matched = $self->assembler->source($^R);
    return wantarray ? (NFC($1), NFC($2), NFC($self->pattern_string_map->{$matched})) : NFC($1);
#   my $long_designators = $self->pattern_long_map->{ $pattern_matched };
#   my $match = Business::CompanyDesignator::Match->new(
#     pattern           => $pattern_matched,
#     long_designators  => $long_designators,
#     languages         => [ map { $self->data->{$_}->{lang} } @$long_designators ],
#   );
  }
  else {
    return wantarray ? ($company_name) : $company_name;
  }
}

1;

__END__

=head1 NAME

Business::CompanyDesignator - perl module for matching and manipulating
company designators appended to company names

=head1 SYNOPSIS

  use Business::CompanyDesignator;
  
  # Constructor
  $bcd = Business::CompanyDesignator->new;
  $bcd = Business::CompanyDesignator->new(datafile => '/path/to/company_designator.yml');

  # Accessors
  # Get a regex for matching designators
  $re = $bcd->regex;
  $company_name =~ $re and say 'matches!';
  $company_name =~ /$re\s*$/ and say 'matches!';

  # Methods
  # Strip any trailing designator from $company_name
  $stripped_name = $bcd->strip_designator($company_name);
  ($stripped_name, $designator, $matched) = $bcd->strip_designator($company_name);


=head1 DESCRIPTION

Business::CompanyDesignator is a perl module for matching and manipulating
the typical company designators appended to company names. It supports both
long forms (e.g. Corporation, Incorporated, Limited etc.) and abbreviations
(e.g. Corp., Inc., Ltd., GmbH etc).

=head1 AUTHOR

Gavin Carr <gavin@openfusion.com.au>

=head1 COPYRIGHT AND LICENCE

Copyright (C) Gavin Carr 2013.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.10.0 or, at
your option, any later version of Perl 5.

=cut

