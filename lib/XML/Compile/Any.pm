package XML::Compile::Any;
our $VERSION = '0.0.1';
# ABSTRACT: turns baubles into trinkets

use strict;
use warnings;
use Carp ();
use Data::Dumper;

use parent 'XML::Compile::Schema';

use XML::Compile::Util;
use XML::Compile::Any::Shims;
use XML::Compile::Any::Translate::Writer::YAML;
use XML::Compile::Any::Translate::Reader::YAML;
use XML::Compile::Any::Translate::Writer::JSON;
use XML::Compile::Any::Translate::Reader::JSON;


sub new {
    my ($class, @schemas) = @_;
    XML::Compile::Any::Translate::Reader::YAML->register('YAMLReader');
    XML::Compile::Any::Translate::Writer::YAML->register('YAMLWriter');
    XML::Compile::Any::Translate::Reader::JSON->register('JSONReader');
    XML::Compile::Any::Translate::Writer::JSON->register('JSONWriter');
    return $class->SUPER::new(\@schemas);
}

sub get_type {
    my ($self, $localname) = @_;

    my @tnses;
    for my $instance ($self->namespaces->allSchemas) {
        for my $ns ($instance->tnses) {
            my $type = XML::Compile::Util::pack_type($ns, $localname);
            my $el = $instance->element($type);
            if (ref $el eq 'XML::LibXML::Element') {
                push @tnses, $type;
            }
        }
    }
    @tnses = reverse sort @tnses;
    return $tnses[0] if @tnses;
}

sub make_any_element_reader_handler {
    my ($self) = @_;
    return sub {
        my ($type, $node, $any, $this) = @_;
        my $reader = $self->compile(READER => $type);
        my ($ns, $localname) = XML::Compile::Util::unpack_type($type);
        my $element;
        eval {
            $element = $reader->($node);
        } or Carp::carp "Couldn't parse this:\n$node" and return;
        return $type, $node;
    }
}

sub make_any_element_writer_handler {
    my ($self) = @_;
    return sub {
        my ($node, $data, $path, $self) = @_;
        return $node if defined $node;
    }
}

sub make_any_element_foreign_reader_handler {
    my ($self) = @_;

    return sub {
        my ($localname, $node, $item) = @_;
        my $type = $self->get_type($localname);

        return @_ unless $type;

        # ignore types in the same namespace as we're currently reading
        my ($item_ns) = XML::Compile::Util::unpack_type($item);
        my ($type_ns) = XML::Compile::Util::unpack_type($type);
        return @_ unless $item_ns ne $type_ns;

        my $writer = $self->compile(
            WRITER => $type,
            use_default_namespace => 1,
        );
        my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
        my $xml = $writer->($doc, $node);

        return $type, $xml;
    }
}

sub make_any_element_foreign_writer_handler {
    my ($self) = @_;

    return sub {
        my ($type, $node) = @_;
        my $reader = $self->compile(READER => $type);
        my ($ns, $localname) = XML::Compile::Util::unpack_type($type);
        my $element;
        eval {
            $element = $reader->($node);
        } or Carp::carp "Couldn't parse this:\n$node" and return;
        return $localname, $element;
    }
}

1;
