# -*- mode: cperl; -*-
use strict;
use warnings;

use Test::More;

use XML::Compile::Any;

my $any = XML::Compile::Any->new( glob 't/xsd/*.xsd' );

sub make_compile {
    my ($self, $keyword) = @_;

    return sub {
        my ($element, $handler) = @_;
        return $self->compile(
            $keyword => $element,
            any_element => $handler,
        );
    };
}

my @formats = qw/JSON YAML/;
my @elements = map $_->elements, $any->namespaces->allSchemas;

plan tests => @formats * @elements;

my %translators =
    map +($_ => make_compile($any => $_)),
    map +("${_}Reader", "${_}Writer"),
    @formats;

my $rhandler = $any->make_any_element_foreign_reader_handler;
my $whandler = $any->make_any_element_foreign_writer_handler;

for my $element (@elements) {
    my $data = eval $any->template(PERL => $element);
    for my $format (@formats) {
        my $reader = $translators{"${format}Reader"}->($element, $rhandler);
        my $writer = $translators{"${format}Writer"}->($element, $whandler);
        is_deeply($reader->($writer->($data)), $data, "$format $element");
    }
}
