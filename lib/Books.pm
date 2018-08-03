#===============================================================================
#
#         FILE: Books.pm
#
#  DESCRIPTION:
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Sebastian Benque (SWRB), sebastian.benque@gmail.com
# ORGANIZATION:
#      VERSION: 1.0
#      CREATED: 2018-08-03 06:13:08
#     REVISION: ---
#===============================================================================

package Book;

# Checking only if values are set with the setter functions and not with the constructor.

use Moose;
use Moose::Util::TypeConstraints;

use namespace::autoclean;
use utf8;


use feature qw(say signatures);
no warnings qw/experimental::signatures recursion/;

use Date::Manip::Date;
use Scalar::Util 'looks_like_number';

use Data::Dumper;

subtype 'YearPublished' => as 'Str' => where { _is_year($_) } =>
  message { 'Year published should be a valid date: ' . Dumper($_) };
coerce 'YearPublished',
  from 'Num', via { _coerce_publish_year($_) },
  from 'Str', via { _coerce_publish_year($_) };

subtype 'DateRead' => as 'Str' => where { _is_date($_) } =>
  message { 'Date read should be a valid date: ' . Dumper($_) };
coerce 'DateRead', from 'Str', via { _coerce_date_read($_) };

subtype 'ISBN' => as 'Str' => where { _is_isbn($_) } =>
  message { 'ISBN should be a valid date: ' . Dumper($_) };
coerce 'ISBN',
  from 'Num', via { _coerce_isbn($_) },
  from 'Str', via { _coerce_isbn($_) };

has 'title'  => ( is  => 'rw',   default => '' );
has 'author' => ( is  => 'rw',   default => '' );
has 'book_index' => (is => 'rw', isa => 'Int', required => 1);
has 'isbn'   => ( isa => 'ISBN', is      => 'rw', coerce => 1, default => '' );
has 'publisher' => (
    is      => 'rw',
    default => '',
);
has 'year_published' => (
    isa     => 'YearPublished',
    is      => 'rw',
    coerce  => 1,
    default => '',
);
has 'date_read' => (
    isa     => 'DateRead',
    is      => 'rw',
    coerce  => 1,
    default => '',
);

sub _is_year ($d) {
    my $date = Date::Manip::Date->new;
    $date->config( DateFormat => 'UK' );

    my $err = $date->parse_format( "%Y", $d );

    ( ( not $err and $d =~ /^\d\d\d\d$/ ) or $d eq '' )
      ? 1
      : 0;
}    ## --- end sub _is_year

sub _is_date ($d) {
    my $date = Date::Manip::Date->new;
    $date->config( DateFormat => 'UK' );

    ( $date->parse_date($d) and ( $d ne '' ) )
      ? 0
      : 1;
}    ## --- end sub _is_date

sub _is_isbn ($isbn) {
    ( _is_isbn_13($isbn) or _is_isbn_10($isbn) ) ? 1 : 0;
}    ## --- end sub _is_isbn

sub _coerce_publish_year ($year) {
    my $date = Date::Manip::Date->new;
    $date->config( DateFormat => 'UK' );

    $date->parse_date($year) ? '' : $date->printf("%Y");
}    ## --- sub _coerce_publish_year

sub _coerce_date_read ($date_read) {
    my $date = Date::Manip::Date->new;
    $date->config( DateFormat => 'UK' );

    $date->parse_date($date_read) ? '' : $date->printf("%Y/%m/%D");
}    ## --- sub _coerce_date_read

sub _coerce_isbn ($isbn) {
    _is_isbn($isbn) ? $isbn : '';
}    ## --- end sub _coerce_isbn

##################
# Helper Functions
##################

sub _is_isbn_13 ($isbn) {
    my @isbn = split '', $isbn;

    return 1 if $isbn eq '';
	return 0 unless looks_like_number($isbn);

    # Retrieve checksum and check length (13 digits)
    return 0
      unless my ($check) = $isbn =~ /^\d{12}(\d)$/;

    # Calculate checksum
    my $sum = 0;
    for ( 1 .. 12 ) {
        if ( $_ % 2 == 1 ) {
            $sum += $isbn[ $_ - 1 ];
        }
        else {
            $sum += 3 * $isbn[ $_ - 1 ];
        }
    }

    # Check if checksum corresponds with calculated checksum
    return 1 if ( 10 - ( $sum % 10 ) ) == $check;
    return 0;
}    ## --- end sub _is_isbn_13

sub _is_isbn_10 ($isbn) {
    0
      # TODO
}    ## --- end sub _is_isbn_10

1;
