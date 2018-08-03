#===============================================================================
#
#         FILE: ReadingList.pm
#
#  DESCRIPTION:
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Sebastian Benque (SWRB), sebastian.benque@gmail.com
# ORGANIZATION:
#      VERSION: 1.0
#      CREATED: 2018-08-03 06:16:19
#     REVISION: ---
#===============================================================================

package ReadingList;

use Moose;
use namespace::autoclean;
use utf8;

use feature qw(say signatures);
no warnings qw/experimental::signatures recursion/;

use FindBin;
use lib $FindBin::Bin;

use Data::Table;
use IO::All -utf8;
use API::OpenLibrary::Search;
use DateTime;
use Books;

has 'db_file_name' => ( is => 'ro', isa => 'Str', required => 1 );
# has 'color'        => ( is => 'ro', isa => 'Str', default  => 'red' );
has 'table' => ( is => 'ro', writer => '_table' );
has 'boolean_map' =>
  ( is => 'ro', writer => '_boolean_map', isa => 'ArrayRef[Bool]' );
has 'position' => ( is => 'ro', writer => '_position', isa => 'Int' );

sub load ($self) {
    if ( -f $self->db_file_name() ) {
        $self->_table( Data::Table::fromFile( $self->db_file_name() ) );
    }
    else {
        # Initialize empty csv table
        $self->_table->(
            Data::Table->new(
                [],
                [
                    "Title",          "Author",
                    "ISBN13",         "Publisher",
                    "Year Published", "Date Read"
                ]
            )
        );
    }
}    ## --- end sub load

sub add ( $self, $title, $author, $isbn, $publisher, $pub_year, $date_read ) {
    $self->table->addRow(
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
}    ## --- end sub add

sub delete ( $self, $book_number ) {
    $book_number--;    # get row index
    $self->table->delRow($book_number);
}    ## --- end sub delete

sub edit ( $self, $book_number, $field, $new_value ) {

}    ## --- end sub edit

sub get ( $self, $book_number ) {
    return map { $self->table->elm( $book_number, $_ ) } "Title", "Author",
      "ISBN13", "Publisher", "Year Published", "Date Read";
}    ## --- end sub get

sub search ( $self, $search_term ) {
    $self->table->match_string( $search_term, 1, 0 );
    $self->boolean_map( $self->table->{OK} )
      ;    # Map which corresponds with the found elements.
}    ## --- emd sub search

sub init_interator ($self) {
    $self->_position(0);
}    ## --- end sub init_iterator

sub next ( $self, $search = 0 ) {
    my $i        = $self->position;
    my $last_row = $self->table->lastRow;
    if ( $search and $i <= $last_row and not $self->boolean_map->[$i] ) {
        $self->_position( $i + 1 );
        $self->next($search);
    }
    elsif ( $i <= $last_row ) {
        $self->_position( $i + 1 );
        return [ $self->get($i) ];
    }
    else {
        return 0;
    }
}    ## --- end sub iterate

sub save ($self) {
    io( $self->db_file_name )->print( $self->table->csv );
}    ## --- end sub save

1;
