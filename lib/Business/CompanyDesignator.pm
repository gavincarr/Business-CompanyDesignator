package Business::CompanyDesignator;

use Mouse;
use FindBin qw($Bin);
use YAML;
use File::ShareDir qw(module_file);
use List::MoreUtils qw(uniq);
use Regexp::Assemble;

our $VERSION = '0.01';

has 'datafile' => ( is => 'ro', default => sub {
  eval { module_file('Business::CompanyDesignator', 'company_designator.yml') }
    # development/test version
    || "$Bin/../share/company_designator.yml";
});

has [ qw(data designator_regex) ]
  => ( is => 'ro', lazy_build => 1 );

sub _build_data {
  my $self = shift;
  YAML::LoadFile($self->datafile);
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

sub _build_designator_regex {
  my $self = shift;

  my @des;
  # For abbreviations, make all periods optional
  push @des, map { s/\./\.?/g; $_ } sort { length $b <=> length $a } $self->abbreviations;
  # Add long_designators verbatim
  push @des, sort { length $b <=> length $a } $self->long_designators;

  # Assemble regex
  my $ra = Regexp::Assemble->new;
  $ra->add(@des);
  return $ra->re;
}

sub strip_designator {
  my $self = shift;
  my $company_name = shift;

  my $re = $self->designator_regex;

  if ($company_name =~ m/(.*?)\s*($re)\s*$/) {
    return wantarray ? ($1, $2) : $1;
  }
  else {
    return wantarray ? ($company_name, undef) : $company_name;
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


  $stripped_name = $bcd->strip_designator($company_name);
  ($stripped_name, $designator) = $bcd->strip_designator($company_name);


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

