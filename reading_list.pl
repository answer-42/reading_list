#!/usr/bin/env perl
#===============================================================================
#
#         FILE: reading_list.pl
#
#        USAGE: ./reading_list.pl
#
#  DESCRIPTION:
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Sebastian Benque (SWRB), sebastian.benque@gmail.com
# ORGANIZATION:
#      VERSION: 1.0
#      CREATED: 06/09/2018 08:24:22 AM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use feature qw(say switch);
no warnings "experimental::smartmatch";

use Data::Table;
use Getopt::Long;
use Scalar::Util 'looks_like_number';
use Term::ReadLine;

# TODO: Add header to all output

# This must be a csv file
use constant DB_FILE_NAME => 'reading_list.csv';

# Exactly one or two argument are needed. If not stop the program.
if ( @ARGV > 2 ) {
    die "Too many arguments. Only one argument required";
}
elsif ( @ARGV < 1 ) {
    die "Too few arguments. Only one argument required";
}

GetOptions(
    "Show"     => \&handler_show,
    "Add"      => \&handler_add,
    "Delete"   => \&handler_delete,
    "Edit"     => \&handler_edit,
    "Import=s" => \&handler_import_goodreads
) or die "Error in command line arguments";

#say $_ for $csv->header();

sub handler_show {
    my $table = Data::Table::fromFile(DB_FILE_NAME);

    foreach my $i ( 0 .. $table->lastRow ) {
        print_row( $table, $i );

        # Unicode problem: wide character
    }
}    ## --- end sub handler_show

sub handler_add {

    # TODO:
    # * check input

    my $table = Data::Table::fromFile(DB_FILE_NAME);

    my $term = new Term::ReadLine "Add";
    $term->ornaments('0');

    my $title  = $term->readline("Title: ");
    my $author = $term->readline("Author: ");

    my $isbn;
    do {
        say "You entered an invalid ISBN number." if defined $isbn;
        $isbn = $term->readline("Isbn: ");
    } while ( not check_isbn($isbn) );

    my $publisher = $term->readline("Publisher: ");
    my $pub_year  = $term->readline("Publication Year: ");

    my $date_read;
    do {
        say "You entered an invalid date." if defined $date_read;
        $date_read = $term->readline("Reading date: ");
    } while ( not check_date($date_read) );

    printf "%20.20s\t", $title;        # Title
    printf "%20.20s\t", $author;       # Author
    printf "%13.13s\t", $isbn;         # ISBN
    printf "%20.20s\t", $publisher;    # Publisher
    printf "%4.4s\t",   $pub_year;     # Year published
    printf "%10.10s\t", $date_read;    # Date read
    print "\n";

    my $validation =
      $term->readline('Do you want to add this following book? (y/n)');

    if ( $validation eq 'y' ) {
        $table->addRow(
            {
                "Title"          => $title,
                "Author"         => $author,
                "ISBN13"         => $isbn,
                "Publisher"      => $publisher,
                "Year Published" => $pub_year,
                "Date Read"      => $date_read
            },
            0
        );

        print_to_file( DB_FILE_NAME, $table->csv );
    }
    else {
        say "Book was not added";
    }

}    ## --- end sub handler_add

sub handler_delete {
    my $table = Data::Table::fromFile(DB_FILE_NAME);

    my $term = new Term::ReadLine "Delete";
    $term->ornaments('0');

    my $row_index =
      $term->readline("Which book do you want to delete? (Insert id) ");
    $row_index--;    # Row number to index.

    # TODO: Check if valid input
    print_row( $table, $row_index );

    my $validation =
      $term->readline("Are you sure you want to delete this book? (y/n) ");

    $table->delRow($row_index);

    if ( $validation eq 'y' ) {
        print_to_file( DB_FILE_NAME, $table->csv );
    }
    else {
        say "Book was not deleted";
    }
}    ## --- end sub handler_delete

sub handler_edit {
    my $table = Data::Table::fromFile(DB_FILE_NAME);

    my $term = new Term::ReadLine "Edit";
    $term->ornaments('0');

    my $row = $term->readline("Which book do you want to edit? (Insert id) ");
    $row--;    # Row number to index.

    my $input;
    do {
        printf "%10.10s\t%20.20s\t%20.20s\t%13.13s\t%20.20s\t%4.4s\t%10.10s\n",
          '', '[1]', '[2]', '[3]', '[4]', '[5]', '[6]';
        print_row( $table, $row );

        my $input = $term->readline(
            "Which field (1-6) do you want to change? To stop editing press q. "
        );

        given ($input) {
            when ('1') {
                my $new_title =
                  $term->readline( "Edit title: ",
                    $table->elm( $row, "Title" ) );
                $table->setElm( $row, "Title", $new_title );
            }
            when ('2') {
                my $new_author = $term->readline( "Edit Author: ",
                    $table->elm( $row, "Author" ) );
                $table->setElm( $row, "Author", $new_author );
            }
            when ('3') {
                my $new_isbn =
                  $term->readline( "Edit Isbn: ",
                    $table->elm( $row, "ISBN13" ) );

                if ( check($new_isbn) ) {
                    $table->setElm( $row, "ISBN13", $new_isbn );
                }
                else {
                    say "Not a valid Isbn number.";
                }
            }
            when ('4') {
                my $new_publisher = $term->readline( "Edit Publisher: ",
                    $table->elm( $row, "Publisher" ) );
                $table->setElm( $row, "Publisher", $new_publisher );
            }
            when ('5') {
                my $new_pub_year = $term->readline( "Edit publication year: ",
                    $table->elm( $row, "Year Published" ) );
                $table->setElm( $row, "Year Published", $new_pub_year );
            }
            when ('6') {
                my $new_date_read = $term->readline( "Edit reading date: ",
                    $table->elm( $row, "D" ) );
                $table->setElm( $row, "Date Read", $new_date_read );
            }
            when ('q') {
                my $validation = $term->readline(
                    "Are you sure you want to save these changes? (y/n) ");

                if ( $validation eq 'y' ) {
                    print_to_file( DB_FILE_NAME, $table->csv );
                }
                else {
                    say "Changes were not saved.";
                }

                exit;
            }
            default {
                say "No valid input";
            }
        }
    } while (1);
}    ## --- end sub handler_edit

sub handler_import_goodreads {
    my ( $opt_name, $input_filename ) = @_;
    my $table = Data::Table::fromFile($input_filename);

    # Import only books from the read shelf
    $table = $table->match_pattern_hash('$_{"Exclusive Shelf"} eq "read"');

    $table->delCols(
        [
            "Book Id",
            "Author l-f",
            "Additional Authors",
            "ISBN",
            "My Rating",
            "Average Rating",
            "Binding",
            "Number of Pages",
            "Original Publication Year",
            "Date Added",
            "Bookshelves",
            "Bookshelves with positions",
            "Exclusive Shelf",
            "My Review",
            "Spoiler",
            "Private Notes",
            "Read Count",
            "Recommended For",
            "Recommended By",
            "Owned Copies",
            "Original Purchase Date",
            "Original Purchase Location",
            "Condition",
            "Condition Description",
            "BCID"
        ]
    );

    # Clean ISBN
    foreach my $i ( 0 .. $table->lastRow ) {

        # Regex: retrieves first consecutive number, eg. '="1234"' -> '1234'
        my ($isbn) = $table->elm( $i, "ISBN13" ) =~ /(\d+)/;

        # Change ISBN to number we got with the regex, or to empty string if no
        # ISBN was given.
        $table->setElm( $i, "ISBN13", $isbn ? $isbn : "" );
    }

    # TODO: Ask if you want to overwrite existing file.
    print_to_file( DB_FILE_NAME, import_goodreads_csv($table)->csv );
}    ## --- end sub handler_import_goodreads

#===  FUNCTION  ================================================================
#         NAME: check_isbn
#      PURPOSE: Checks if given number is a valid ISBN13 number.
#   PARAMETERS: isbn (integer)
#      RETURNS: boolean
#         TODO: More check possible.
#===============================================================================
sub check_isbn {
    my ($isbn) = @_;
    my @isbn = split '', $isbn;

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
}    ## --- end sub check_isbn

sub print_row {
    my ( $table, $row_index ) = @_;

    printf "%10.10s\t", $row_index + 1;                            # Counter
    printf "%20.20s\t", $table->elm( $row_index, "Title" );        # Title
    printf "%20.20s\t", $table->elm( $row_index, "Author" );       # Author
    printf "%13.13s\t", $table->elm( $row_index, "ISBN13" );       # ISBN
    printf "%20.20s\t", $table->elm( $row_index, "Publisher" );    # Publisher
    printf "%4.4s\t",
      $table->elm( $row_index, "Year Published" );    # Year published
    printf "%10.10s\t", $table->elm( $row_index, "Date Read" );    # Date read
    print "\n";

}    ## --- end sub print_row

sub check_date {
    my ($date) = @_;
    my ( $year, $month, $day ) = $date =~ /(\d\d\d\d)\/(\d\d)\/(\d\d)/;

    return 1 if $year and $month and $day and $month <= 12 and $day <= 31;
    return 0;
}    ## --- end sub check_date

sub print_to_file {
    my ( $output_filename, $output ) = @_;

    open my $fh, '>', $output_filename
      or die "$0 : failed to open  output file '$output_filename' : $!\n";

    print $fh $output;

    close $fh
      or warn "$0 : failed to close output file '$output_filename' : $!\n";
}    ## --- end sub print_to_file
