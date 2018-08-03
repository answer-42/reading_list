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
#      VERSION: 1.2 
#      CREATED: 06/09/2018 08:24:22 AM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use feature qw/say signatures/;
no warnings qw/experimental::smartmatch experimental::signatures/;

use Cwd qw/abs_path/;
use FindBin;
use lib abs_path("$FindBin::Bin/../lib");

use Getopt::Std;
use Term::ReadLine;
use Config::Tiny;
use Term::ANSIColor;
use DateTime;

use Books;
use ReadingList;

### Initalize
#############

binmode( STDOUT, ":encoding(UTF-8)" );

# Read from config file. Must be placed in the same folder as the script.
my $config = Config::Tiny->read( $ENV{HOME} . '/.reading_list.ini' );

my $COLOR = $config->{all}->{color};
my $reading_list =
  ReadingList->new( db_file_name => $config->{all}->{csv_file}, );

$reading_list->load;

sub init_term () {
    my $term    = Term::ReadLine->new("Reading List");
    my $attribs = $term->Attribs;
    $attribs->{completion_entry_function} =
      $attribs->{list_completion_function};

    my @completion_words_list;
    $reading_list->init_interator;
    while ( my $book = $reading_list->next ) {
        push @completion_words_list,
          ( $book->{title}, $book->{author}, $book->{publisher} );
    }

    $attribs->{completion_word} = [@completion_words_list];

    $term->ornaments('0');
    return $term;
}

# Main
######

my %opts;
getopts( 'saode:il:', \%opts );

if ( $opts{s} ) {
    handler_show( $reading_list, $COLOR );
}
elsif ( $opts{a} ) {
    my $term = init_term();
    handler_add( $reading_list, $term );
}
elsif ( $opts{o} ) {

    #    handler_ol( $table, $term );
    say 'o';
}
elsif ( $opts{d} ) {
    my $term = init_term();
    handler_delete( $reading_list, $term );
}
elsif ( $opts{e} ) {
    my $term = init_term();
    handler_edit( $reading_list, $opts{e}, $term );
}
elsif ( $opts{i} ) {

    #    handler_import_goodreads( $term, $opts{i} );
    say 'i';
}
elsif ( $opts{l} ) {
    handler_look( $reading_list, $opts{l}, $COLOR );
}

# Subroutines
#############

sub handler_look ( $reading_list, $search_term, $color ) {
    $reading_list->search($search_term);
    $reading_list->init_interator;
    while ( my $book = $reading_list->next(1) ) {
        print_book( $book, $color );
    }
}    ## --- end sub handler_look

sub handler_show ( $reading_list, $color = 1 ) {
    $reading_list->init_interator;
    while ( my $book = $reading_list->next ) {
        print_book( $book, $color );
    }
}    ## --- end sub handler_show

sub print_book ( $book, $color = 1 ) {
    printf "%10.10s\t", $book->book_index + 1;    # Counter
    print color('red bold') if $color;
    printf "%-20.20s\t", $book->title;            # Title
    print color('green') if $color;
    printf "%-20.20s\t", $book->author;           # Author
    print color('reset') if $color;
    printf "%-13.13s\t", $book->isbn;              # ISBN
    printf "%-20.20s\t", $book->publisher;         # Publisher
    printf "%-4.4s\t",   $book->year_published;    # Year published
    printf "%-10.10s\t", $book->date_read;         # Date read
    print "\n";
}    ## --- end sub print_row

sub handler_add ( $reading_list, $term ) {
    my $book = Books->new;
    $book->title( prompt_title($term) );
    $book->author( prompt_author($term) );
    $book->isbn( prompt_isbn($term) );
    $book->publisher( prompt_publisher($term) );
    $book->year_published( prompt_pub_year($term) );
    $book->date_read( prompt_date_read($term) );

    $reading_list->add($book);

    print_book($book);
    validate_save_changes( $reading_list, $term );
}    ## --- end sub handler_add

sub prompt_title ($term) {
    $term->readline("Title: ");
}    ## --- end sub prompt_title

sub prompt_author ($term) {
    $term->readline("Author: ");
}    ## --- end sub prompt_title

sub prompt_isbn ($term) {
    $term->readline("Isbn: ");
}    ## --- end sub prompt_title

sub prompt_publisher ($term) {
    $term->readline("Publisher: ");
}    # --- end sub prompt_publisher

sub prompt_pub_year ($term) {
    $term->readline("Publication Year: ");
}    ## --- end sub prompt_title

sub prompt_date_read ($term) {
    $term->readline( "Reading date: ", DateTime->now->ymd('/') );
}    ## --- end sub prompt_date_read

sub handler_delete ( $reading_list, $term ) {
    my $book_index =
      $term->readline("Which book do you want to delete? (Insert id) ");
    $book_index--;    # Book number to index.

    # Book index in range
    unless ( $reading_list->is_valid_book_index($book_index) ) {
        say "Book number not in range.";
        return;
    }

    # Show book to delete
    print_book( $reading_list->get($book_index) );

    $reading_list->delete($book_index);
    validate_save_changes( $reading_list, $term );
}    ## --- end sub handler_delete

sub validate_save_changes ( $reading_list, $term ) {
    my $validation =
      $term->readline("Are you sure you want to save the changes? (y/n) ");
    if ( $validation eq 'y' ) {
        $reading_list->save;
    }
    else {
        say "Changes were not saved.";
    }
}    ## --- end sub validate_save_changes

sub handler_edit ( $reading_list, $book_index, $term ) {
    $book_index--;    # Book number to index.
                      # Book index in range
    unless ( $reading_list->is_valid_book_index($book_index) ) {
        say "Book number not in range.";
        return;
    }

    my $book = $reading_list->get($book_index);
    my $input;
    do {
        print_book($book);
        my $input = $term->readline(
"Change [t]itle, [a]uthor, [i]sbn, [p]ublisher, publication [y]ear or [d]ate read? To stop editing press q. "
        );

        if ( $input eq 't' ) {
            $book->title( $term->readline( "Edit Title: ", $book->title ) );
        }
        elsif ( $input eq 'a' ) {
            $book->author( $term->readline( "Edit Author: ", $book->author ) );
        }
        elsif ( $input eq 'i' ) {
            $book->isbn( $term->readline( "Edit ISBN: ", $book->isbn ) );
        }
        elsif ( $input eq 'p' ) {
            $book->publisher(
                $term->readline( "Edit Publisher: ", $book->publisher ) );
        }
        elsif ( $input eq 'y' ) {
            $book->year_published(
                $term->readline(
                    "Edit Year Published: ",
                    $book->year_published
                )
            );
        }
        elsif ( $input eq 'd' ) {
            $book->date_read(
                $term->readline( "Edit Publisher: ", $book->date_read ) );
        }
        elsif ( $input eq 'q' ) {
            $reading_list->edit( $book_index, $book );
            validate_save_changes( $reading_list, $term );
            return;
        }
        else {
            say "No valid input";
        }
    } while (1);
}    ## --- end sub handler_edit

#sub handler_import_goodreads ( $term, $input_filename ) {
#    my $table = Data::Table::fromFile($input_filename);
#
#    # Import only books from the read shelf
#    $table = $table->match_pattern_hash('$_{"Exclusive Shelf"} eq "read"');
#
#    $table->delCols(
#        [
#            "Book Id",
#            "Author l-f",
#            "Additional Authors",
#            "ISBN",
#            "My Rating",
#            "Average Rating",
#            "Binding",
#            "Number of Pages",
#            "Original Publication Year",
#            "Date Added",
#            "Bookshelves",
#            "Bookshelves with positions",
#            "Exclusive Shelf",
#            "My Review",
#            "Spoiler",
#            "Private Notes",
#            "Read Count",
#            "Recommended For",
#            "Recommended By",
#            "Owned Copies",
#            "Original Purchase Date",
#            "Original Purchase Location",
#            "Condition",
#            "Condition Description",
#            "BCID"
#        ]
#    );
#
#    # Clean ISBN
#    foreach my $i ( 0 .. $table->lastRow ) {
#
#        # Regex: retrieves first consecutive number, eg. '="1234"' -> '1234'
#        my ($isbn) = $table->elm( $i, "ISBN13" ) =~ /(\d+)/;
#
#        # Change ISBN to number we got with the regex, or to empty string if no
#        # ISBN was given.
#        $table->setElm( $i, "ISBN13", $isbn ? $isbn : "" );
#    }
#
#    if ( -f $DB_FILE_NAME ) {
#        my $validation = $term->readline(
#            "File already exists. Do you want to overwrite it? (y/n)");
#        if ( $validation eq 'y' ) {
#            io($DB_FILE_NAME)->print( import_goodreads_csv($table)->csv );
#        }
#        else { say "File was not saved." }
#    }
#    else {
#        io($DB_FILE_NAME)->print( import_goodreads_csv($table)->csv );
#    }
#}    ## --- end sub handler_import_goodreads
#
##===  FUNCTION  ================================================================
##         NAME: check_isbn
##      PURPOSE: Checks if given number is a valid ISBN13 number or '-'.
##   PARAMETERS: isbn (integer)
##      RETURNS: boolean
##===============================================================================

#sub handler_ol ( $table, $term ) {
#    my $ol = API::OpenLibrary::Search->new();
#
#    my $search_term = $term->readline("Search: ");
#    $ol->search($search_term);
#    if ( $ol->status_code != 200 ) {
#        say "Ther is a problem with the connection. Error code: ",
#          $ol->status_code;
#        return;
#    }
#    elsif ( $ol->num_found == 0 ) {
#        say "No books found.";
#        return;
#    }
#
#    foreach my $row_index ( 0 .. $#{ $ol->results } ) {
#        print_row(
#            $row_index,                                           # Row index
#            $ol->results->[$row_index]->{title} // '',            # Title
#            $ol->results->[$row_index]->{author_name}->[0] // '', # Author
#            $ol->results->[$row_index]->{isbn}->[0] // '',        # ISBN
#            $ol->results->[$row_index]->{publisher}->[0] // '',   # Publisher
#            $ol->results->[$row_index]->{publish_year}->[0]
#              // '',                                              # Publish year
#        );
#    }
#
#    my $row_index = $term->readline('Which book do you want to add? ');
#    $row_index--;
#    if ( $row_index < 0 or $row_index > $ol->results->@* ) {
#        say 'Invalid input. No book added.';
#        return;
#    }
#
#    my $date_read = prompt_date_read($term);
#
#    add_book(
#        $table,
#        $term,
#        $ol->results->[$row_index]->{title} // '',
#        $ol->results->[$row_index]->{author_name}->[0] // '',
#        $ol->results->[$row_index]->{isbn}->[0] // '',
#        $ol->results->[$row_index]->{publisher}->[0] // '',
#        $ol->results->[$row_index]->{publish_year}->[0] // '',
#        $date_read
#    );
#}    ## --- end sub handler_add
#

