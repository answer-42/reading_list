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
use feature 'say';

use Data::Table;
use Getopt::Long;

# This must be a csv file
use constant DB_FILE_NAME => 'reading_list.csv';

# Exactly one argument is needed. If not stop the program.
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
    "Import=s" => \&handler_import_goodreads
) or die "Error in command line arguments";

# TODO
# * Add numbering to show_table to make delete possible
# * Check that only one argument is given at any time

# show_table($csv);

#say $_ for $csv->header();

sub handler_show {
    my $table = Data::Table::fromFile(DB_FILE_NAME);

    show_table($table);

}    ## --- end sub handler_show

sub handler_add {

    # TODO:
    # * check input
    # * Add database

    my $csv;

    print "Author:";
    my $author = <STDIN>;
    chomp $author;

    print "Title:";
    my $title = <STDIN>;
    chomp $title;

    print "Isbn:";
    my $isbn = <STDIN>;
    chomp $isbn;

    print "Publisher::";
    my $publisher = <STDIN>;
    chomp $publisher;

    print say "Publication Year:";
    my $pub_year = <STDIN>;
    chomp $pub_year;

    print "Reading date::";
    my $date_read = <STDIN>;
    chomp $date_read;

    print_to_file(
        DB_FILE_NAME,
        add_book(
            $csv, $title, $author, $isbn, $publisher, $pub_year, $date_read
        )
    );
}    ## --- end sub handler_add

sub handler_delete {
    my ($par1) = @_;
    return;
}    ## --- end sub handler_delete

sub handler_import_goodreads {
    my ( $opt_name, $input_filename ) = @_;
    my $table = Data::Table::fromFile($input_filename);

    print_to_file( DB_FILE_NAME, import_goodreads_csv($table)->csv );
}    ## --- end sub handler_import_goodreads

#===  FUNCTION  ================================================================
#         NAME: import_goodreads_csv
#      PURPOSE: Using a csv file from Goodreads to create a csv file with the
#      			following collumns: title, author, ISBN13,  publisher,
#      			year published, date read
#   PARAMETERS: Data::Table object from goodreads csv file
#      RETURNS: Data::Table object
#===============================================================================
sub import_goodreads_csv {
    my ($csv) = @_;

    $csv = $csv->match_pattern_hash('$_{"Exclusive Shelf"} eq "read"');

    $csv->delCols(
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
    foreach my $i ( 0 .. $csv->lastRow ) {

        # Regex: retrieves first consecutive number, eg. '="1234"' -> '1234'
        my ($isbn) = $csv->elm( $i, "ISBN13" ) =~ /(\d+)/;

        # Change ISBN to number we got with the regex, or to empty string if no
        # ISBN was given.
        $csv->setElm( $i, "ISBN13", $isbn ? $isbn : "" );
    }

    return $csv;
}    ## --- end sub import_goodreads_csv

#===  FUNCTION  ================================================================
#         NAME: add_book
#      PURPOSE: Add title, author, isbn, publisher, year published, date read to
#      			existing csv.
#   PARAMETERS: Data::Table object, 6 strings
#      RETURNS: Data::Table object
#         TODO: add error checking
#===============================================================================
sub add_book {
    my ( $csv, $title, $author, $isbn, $publisher, $pub_year, $date_read ) = @_;

    $csv->addRow(
        {
            "Title"          => $title,
            "Author"         => $author,
            "ISBN13"         => $isbn,
            "Publisher"      => $publisher,
            "Year Published" => $pub_year,
            "Date Read"      => $date_read
        }
    );

    return $csv;
}    ## --- end sub add_book

#===  FUNCTION  ================================================================
#         NAME: show_table
#      PURPOSE: Print the csv table
#   PARAMETERS: Data::Table object
#      RETURNS: undef
#         TODO: Add $csv->header()>
#===============================================================================
sub show_table {
    my ($csv) = @_;

    foreach my $i ( 0 .. $csv->lastRow ) {

        # Unicode problem: wide character
        printf "%10.10s\t", $i + 1;                             # Counter
        printf "%20.20s\t", $csv->elm( $i, "Title" );           # Title
        printf "%20.20s\t", $csv->elm( $i, "Author" );          # Author
        printf "%13.13s\t", $csv->elm( $i, "ISBN13" );          # ISBN
        printf "%20.20s\t", $csv->elm( $i, "Publisher" );       # Publisher
        printf "%4.4s\t",   $csv->elm( $i, "Year Published" );  # Year published
        printf "%10.10s\t", $csv->elm( $i, "Date Read" );       # Date read
        print "\n";
    }
    return;
}    ## --- end sub show_table

#===  FUNCTION  ================================================================
#         NAME: check_isbn
#      PURPOSE: Checks if given number is a valid ISBN13 number.
#   PARAMETERS: isbn (integer)
#      RETURNS: boolean
#         TODO: More check possible.
#===============================================================================
sub check_isbn {
    my ($isbn) = @_;

    # Calculate checksum
    my @isbn = split '', $isbn;
    my $sum = 0;
    for ( 1 .. 12 ) {
        if ( $_ % 2 == 1 ) {
            $sum += $isbn[ $_ - 1 ];
        }
        else {
            $sum += 3 * $isbn[ $_ - 1 ];
        }
    }

    # Retrieve checksum and check length (13 digits)
    return 0
      unless my ($check) = $isbn =~ /^\d{12}(\d)$/;

    # Check if checksum corresponds with calculated checksum
    return 1 if ( 10 - ( $sum % 10 ) ) == $check;
    return 0;
}    ## --- end sub check_isbn

sub print_to_file {
    my ( $output_filename, $output ) = @_;

    open my $fh, '>', $output_filename
      or die "$0 : failed to open  output file '$output_filename' : $!\n";

    print $fh $output;

    close $fh
      or warn "$0 : failed to close output file '$output_filename' : $!\n";
}    ## --- end sub print_to_file

