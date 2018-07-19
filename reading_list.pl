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
use Getopt::Std;
use Scalar::Util 'looks_like_number';
use Term::ReadLine;
use IO::All -utf8;
use API::OpenLibrary::Search;
use Config::Tiny;
use Term::ANSIColor;
use DateTime;

binmode( STDOUT, ":encoding(UTF-8)" );

# Read from config file. Must be placed in the same folder as the script.
my $config = Config::Tiny->read($ENV{HOME} . '/.reading_list.ini');

my $DB_FILE_NAME = $config->{all}->{csv_file};
my $COLOR        = $config->{all}->{color};

# s = show
# a = add
# o = openlibrary
# d = delete
# e = edit
# i = import, takes and argument
my %opts;
getopts( 'saodei:', \%opts );

if ( $opts{s} ) {
    handler_show();
}
elsif ( $opts{a} ) {
    handler_add();
}
elsif ( $opts{o} ) {
    handler_ol();
}
elsif ( $opts{d} ) {
    handler_delete();
}
elsif ( $opts{e} ) {
    handler_edit();
}
elsif ( $opts{i} ) {
    handler_import_goodreads( $opts{i} );
}

sub handler_show {
    my $table = Data::Table::fromFile($DB_FILE_NAME);

    foreach my $i ( 0 .. $table->lastRow ) {
        print_row( $table, $i );
    }
}    ## --- end sub handler_show

sub handler_add {
    my $term = Term::ReadLine->new("Add");
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
        $date_read =
          $term->readline( "Reading date: ", DateTime->now->ymd('/') );
    } while ( not check_date($date_read) );

    add_book( $title, $author, $isbn, $publisher, $pub_year, $date_read );
}    ## --- end sub handler_add

sub handler_ol {
    my $table = Data::Table::fromFile($DB_FILE_NAME);
    my $ol    = API::OpenLibrary::Search->new();
    my $term  = Term::ReadLine->new("OL");
    $term->ornaments('0');

    my $search_term = $term->readline("Search: ");
    $ol->search($search_term);
    if ( $ol->status_code != 200 ) {
        say "Ther is a problem with the connection. Error code: ",
          $ol->status_code;
        return;
    }
    elsif ( $ol->num_found == 0 ) {
        say "No books found.";
        return;
    }

    foreach my $i ( 0 .. $#{ $ol->results } ) {
        printf "%5.5s\t", $i + 1;
        printf "%-20.20s\t", $ol->results->[$i]->{title} // '';    # Title
        printf "%-20.20s\t",
          $ol->results->[$i]->{author_name}->[0] // '';    # Author
        printf "%-13.13s\t", $ol->results->[$i]->{isbn}->[0]      // '';  # ISBN
        printf "%-20.20s\t", $ol->results->[$i]->{publisher}->[0] // '';  # ISBN
        printf "%-4.4s\t", $ol->results->[$i]->{publish_year}->[0] // ''; # ISBN
        print "\n";
    }

    my $row_index = $term->readline('Which book do you want to add? ');
    $row_index--;
    if ( $row_index < 0 or $row_index > $#{ $ol->results } ) {
        say 'Invalid input. No book added.';
        return;
    }

    my $date_read;
    do {
        say "You entered an invalid date." if defined $date_read;
        $date_read = $term->readline( "When did you read this book?: ",
            DateTime->now->ymd('/') );
    } while ( not check_date($date_read) );

    add_book(
        $ol->results->[$row_index]->{title}             // '',
        $ol->results->[$row_index]->{author_name}->[0]  // '',
        $ol->results->[$row_index]->{isbn}->[0]         // '',
        $ol->results->[$row_index]->{publisher}->[0]    // '',
        $ol->results->[$row_index]->{publish_year}->[0] // '',
        $date_read
    );
}    ## --- end sub handler_add

sub handler_delete {
    my $table = Data::Table::fromFile($DB_FILE_NAME);

    my $term = Term::ReadLine->new("Delete");
    $term->ornaments('0');

    my $row_index =
      $term->readline("Which book do you want to delete? (Insert id) ");
    $row_index--;    # Row number to index.

    print_row( $table, $row_index );

    my $validation =
      $term->readline("Are you sure you want to delete this book? (y/n) ");
    if ( $validation eq 'y' ) {
        $table->delRow($row_index);
        io($DB_FILE_NAME)->print( $table->csv );
    }
    else {
        say "Book was not deleted";
    }
}    ## --- end sub handler_delete

sub handler_edit {
    my $table = Data::Table::fromFile($DB_FILE_NAME);
    my $term  = Term::ReadLine->new("Edit");
    $term->ornaments('0');

    my $row_index =
      $term->readline("Which book do you want to edit? (Insert id) ");
    $row_index--;    # Row number to index.

    my $input;
    do {
        printf "%10.10s\t%20.20s\t%20.20s\t%13.13s\t%20.20s\t%4.4s\t%10.10s\n",
          '', '[1]', '[2]', '[3]', '[4]', '[5]', '[6]';
        print_row( $table, $row_index );

        my $input = $term->readline(
            "Which field (1-6) do you want to change? To stop editing press q. "
        );

        given ($input) {
            when ('1') {
                $table = change_field( $term, $table, $row_index, "Title" );
            }
            when ('2') {
                $table = change_field( $term, $table, $row_index, "Author" );
            }
            when ('3') {
                my $new_isbn =
                  $term->readline( "Edit Isbn: ",
                    $table->elm( $row_index, "ISBN13" ) );

                if ( check_isbn($new_isbn) ) {
                    $table->setElm( $row_index, "ISBN13", $new_isbn );
                }
                else {
                    say "Not a valid Isbn number.";
                }
            }
            when ('4') {
                $table = change_field( $term, $table, $row_index, "Publisher" );
            }
            when ('5') {
                $table =
                  change_field( $term, $table, $row_index, "Year Published" );
            }
            when ('6') {
                my $new_date_read = $term->readline( "Edit reading date: ",
                    $table->elm( $row_index, "Date Read" ) );

                if ( check_date($new_date_read) ) {
                    $table->setElm( $row_index, "Date Read", $new_date_read );
                }
                else {
                    say "Not a valid date.";
                }
            }
            when ('q') {
                my $validation = $term->readline(
                    "Are you sure you want to save these changes? (y/n) ");
                if ( $validation eq 'y' ) {
                    print_to_file( $DB_FILE_NAME, $table->csv );
                }
                else {
                    say "Changes were not saved.";
                }

                return;
            }
            default {
                say "No valid input";
            }
        }
    } while (1);
}    ## --- end sub handler_edit

sub handler_import_goodreads {
    my $input_filename = shift;
    my $table          = Data::Table::fromFile($input_filename);

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

    if ( -f $DB_FILE_NAME ) {
        my $term = Term::ReadLine->new("Import");
        $term->ornaments('0');

        my $validation = $term->readline(
            "File already exists. Do you want to overwrite it? (y/n)");

        given ($validation) {
            when ('y') {
                io($DB_FILE_NAME)->print( import_goodreads_csv($table)->csv );
            }
            default { say "File was not saved." }
        }
    }
    else {
        io($DB_FILE_NAME)->print( import_goodreads_csv($table)->csv );
    }
}    ## --- end sub handler_import_goodreads

#===  FUNCTION  ================================================================
#         NAME: check_isbn
#      PURPOSE: Checks if given number is a valid ISBN13 number or '-'.
#   PARAMETERS: isbn (integer)
#      RETURNS: boolean
#===============================================================================
sub check_isbn {
    my ($isbn) = @_;
    my @isbn = split '', $isbn;

    return 1 if $isbn eq '-';
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

    printf "%10.10s\t", $row_index + 1;    # Counter
    print color('bold red') if $COLOR;
    printf "%-20.20s\t", $table->elm( $row_index, "Title" );    # Title
    print color('green') if $COLOR;
    printf "%-20.20s\t", $table->elm( $row_index, "Author" );    # Author
    print color('reset') if $COLOR;
    printf "%-13.13s\t", $table->elm( $row_index, "ISBN13" );       # ISBN
    printf "%-20.20s\t", $table->elm( $row_index, "Publisher" );    # Publisher
    printf "%-4.4s\t",
      $table->elm( $row_index, "Year Published" );    # Year published
    printf "%-10.10s\t", $table->elm( $row_index, "Date Read" );    # Date read
    print "\n";

}    ## --- end sub print_row

sub change_field {
    my ( $term, $table, $row_index, $col ) = @_;

    my $new_title =
      $term->readline( "Edit " . $col . ": ", $table->elm( $row_index, $col ) );
    $table->setElm( $row_index, $col, $new_title );

    return $table;
}    ## --- end sub change_field

sub check_date {
    my ($date) = @_;
    my ( $year, $month, $day ) = $date =~ /(\d\d\d\d)\/(\d\d)\/(\d\d)/;

    return 1 if $date eq '-';
    return 1 if $year and $month and $day and $month <= 12 and $day <= 31;
    return 0;
}    ## --- end sub check_date

sub add_book {
    my ( $title, $author, $isbn, $publisher, $pub_year, $date_read ) = @_;

    my $table = Data::Table::fromFile($DB_FILE_NAME);
    my $term  = Term::ReadLine->new("Add");
    $term->ornaments('0');

    printf "%-20.20s\t", $title;        # Title
    printf "%-20.20s\t", $author;       # Author
    printf "%-13.13s\t", $isbn;         # ISBN
    printf "%-20.20s\t", $publisher;    # Publisher
    printf "%-4.4s\t",   $pub_year;     # Year published
    printf "%-10.10s\t", $date_read;    # Date read
    print "\n";

    my $validation = $term->readline('Do you want to add this book? (y/n)');
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
        io($DB_FILE_NAME)->print( $table->csv );
    }
    else {
        say "Book was not added";
    }

    return;
}    ## --- end sub add_book
