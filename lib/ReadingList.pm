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

use Moo;
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

has 'db_file_name' => ( is => 'ro', required => 1 );
has 'table'        => ( is => 'rwp' );
has 'boolean_map'  => ( is => 'rwp' );
has 'position'     => ( is => 'rwp' );

sub load ($self) {
    if ( -f $self->db_file_name() ) {
        $self->_set_table( Data::Table::fromFile( $self->db_file_name() ) );
    }
    else {
        # Initialize empty csv table
        $self->_set_table->(
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

sub add ( $self, $book ) {
    $self->table->addRow(
        {
            "Title"          => $book->title,
            "Author"         => $book->author,
            "ISBN13"         => $book->isbn,
            "Publisher"      => $book->publisher,
            "Year Published" => $book->year_published,
            "Date Read"      => $book->date_read
        },
        0
    );
}    ## --- end sub add

sub delete ( $self, $book_index ) {
    $self->table->delRow($book_index);
}    ## --- end sub delete

sub edit ( $self, $book_number, $field, $new_value ) {

}    ## --- end sub edit

sub get ( $self, $book_index ) {
    my $book = Books->new( book_index => $book_index );
    $book->title( $self->table->elm( $book_index, "Title" ) );
    $book->publisher( $self->table->elm( $book_index, "Publisher" ) );
    $book->author( $self->table->elm( $book_index, "Author" ) );
    $book->isbn( $self->table->elm( $book_index, "ISBN13" ) );
    $book->year_published( $self->table->elm( $book_index, "Year Published" ) );
    $book->date_read( $self->table->elm( $book_index, "Date Read" ) );
    return $book;
}    ## --- end sub get

sub search ( $self, $search_term ) {
    $self->table->match_string( $search_term, 1, 0 );
    $self->_set_boolean_map( $self->table->{OK} )
      ;    # Map which corresponds with the found elements.
}    ## --- emd sub search

sub init_interator ($self) {
    $self->_set_position(0);
}    ## --- end sub init_iterator

sub next ( $self, $search = 0 ) {
    my $i        = $self->position;
    my $last_row = $self->table->lastRow;
    if ( $search and $i <= $last_row and not $self->boolean_map->[$i] ) {
        $self->_set_position( $i + 1 );
        $self->next($search);
    }
    elsif ( $i <= $last_row ) {
        $self->_set_position( $i + 1 );
        return $self->get($i);
    }
    else {
        return 0;
    }
}    ## --- end sub iterate

sub save ($self) {
    binmode( STDOUT, ":encoding(UTF-8)" );
    io( $self->db_file_name )->print( $self->table->csv );
}    ## --- end sub save

1;
