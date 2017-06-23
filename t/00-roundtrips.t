# -*- mode: cperl; -*-
use strict;
use warnings;

use Test::More;

use List::Util qw( shuffle );
use Data::Dumper;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Indent    = 1;

use XML::Compile::Any;

my $any = XML::Compile::Any->new( glob 't/xsd/*.xsd' );

sub make_compile {
    my ( $self, $keyword ) = @_;

    return sub {
        my ( $element, $handler ) = @_;
        return $self->compile(
            $keyword    => $element,
            any_element => $handler,
        );
    };
}

my @formats = qw( JSON YAML );

my %translator =
  map +( $_ => make_compile( $any => $_ ) ),
  map +( "${_}Reader", "${_}Writer" ),
  @formats;

my @elements = shuffle grep /coord/,
 map $_->elements, $any->namespaces->allSchemas;

plan tests => @formats * @elements;

for my $element (@elements) {
    my $data = eval $any->template( PERL => $element );
    for my $format (@formats) {
        my $reader = $translator{"${format}Reader"}
          ->( $element, $any->make_any_element_foreign_reader_handler );
        my $writer = $translator{"${format}Writer"}
          ->( $element, $any->make_any_element_foreign_writer_handler );
        is_deeply( $reader->( $writer->($data) ), $data, "$format $element" )
          or diag Dumper([ $reader->( $writer->($data) ), $writer->($data), $data] );
    }
}
