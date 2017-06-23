#!perl -T
# -*- mode: cperl; -*-
use 5.006;
use strict;
use warnings;
use Test::More;
use Data::Dumper;

use XML::Compile::Any;

#plan tests => 1;

BEGIN {
    use_ok( 'XML::Compile::Any' ) || print "Bail out!\n";
}

my $any = XML::Compile::Any->new(glob 't/xsd/*.xsd');

sub make_compile {
    my ($self, $keyword) = @_;

    return sub {
        my ($element, $handler) = @_;
        return $self->compile(
            $keyword => $element,
            any_element => $handler
        );
    };
}

my @formats = qw( JSON YAML );

my %translator =
    map +( $_ => make_compile($_) ),
    map +( "${_}Reader", "${_}Writer" ),
    @formats;

my @elements = map { $_->elements } $any->namespaces->allSchemas;

for my $element (@elements) {
    my $data = eval $any->template(PERL => $element);

    for my $format (@formats) {
        my ($reader, $writer) = @{translator}{map { "$format$_" } qw/Reader Writer/};
        $reader->
    }
#     my %structs;

#     for my $writer (sort keys %writers) {
#         my $make_serializer = $writers{$writer};
#         my $serializer = $make_serializer->($element, $any->make_any_element_foreign_writer_handler);
#         $structs{$writer} = $serializer->($data);
#     }

#     for my $reader (sort keys %readers) {
#         my $make_deserializer = $readers{$reader};
#         my $deserializer = $make_deserializer->($element, $any->make_any_element_foreign_reader_handler);
#         my $deserialized_data = $deserializer->($serialized_data);
#     }
}

=pod
t/xsd
 /xml
 /json
 /yaml

perl data structure => xml => perl datastructure
perl data structure => yaml => perl datastructure
perl data structure => json => perl datastructure

=cut

diag( "Testing XML::Compile::Any $XML::Compile::Any::VERSION, Perl $], $^X" );
done_testing();
