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

use Module::Pluggable search_path => ['XML::Compile::Any::Translate::Reader',
                                      'XML::Compile::Any::Translate::Writer'],
                      require => 1;

sub new {
    my ($class, @schemas) = @_;

    my $self = $class->SUPER::new(\@schemas);
    for my $translator ($self->plugins) {
        $translator->register(_mod2kw($translator));
    }
    return $self;
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

sub get_elements {
    my ($self) = @_;
    my @elements;
    for my $instance ($self->namespaces->allSchemas) {
        push @elements, $instance->elements;
    }
    return @elements;
}

sub make_any_element_handler {
    my ($self, $keyword) = @_;

    my %mod2kw = map {_mod2kw($_) => $_} $self->plugins;
    if (exists $mod2kw{$keyword}) {
        my $rw = _mod2rw($mod2kw{$keyword});
        if ($rw =~ /Reader/) {
            return $self->make_any_element_foreign_reader_handler;
        }
        elsif ($rw =~ /Writer/) {
            return $self->make_any_element_foreign_writer_handler;
        }
        else {
            die sprintf 'unknown keyword: %s', $keyword;
        }
    }
    elsif ($keyword eq 'READER') {
        return $self->make_any_element_reader_handler;
    }
    elsif ($keyword eq 'WRITER') {
        return $self->make_any_element_writer_handler;
    }
    else {
        die sprintf 'unknown keyword: %s', $keyword;
    }

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
        return $type, $node
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

sub _mod2kw {
    my ($mod) = @_;
    return join '', (split /::/, $mod)[-1,-2];
}

sub _mod2rw {
    my ($mod) = @_;
    return (split /::/, $mod)[-2];
}

1;

__END__

=pod

=head1 NAME

XML::Compile::Any - Compile any XML to any format

=head1 SYNOPSIS

use XML::Compile::Any;
use XML::LibXML;

my $any = XML::Compile::Any->new(glob 't/xsd/*.xsd');

# XML reader
my $reader = $any->compile(
    READER => $element,
    any_element => $any->make_any_element_reader_handler
);
my $wf = $reader->('/home/psilva/workflow.xml');

# XML writer
my $writer = $any->compile(
    WRITER => $element,
    any_element => $any->make_any_element_writer_handler,
    use_default_namespace => 1,
);
my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
my $xml = $writer->($doc, $wf);
$doc->setDocumentElement($xml);
print $doc->serialize(1);

=head1 DESCRIPTION

This class extends XML::Compile to handle xs:any elements using
reasonable heuristics and to provide marshalling and unmarshalling to
and from any number of (pluggable) formats.

=head1 METHODS

=over 4

=item XML::Compile::Any-E<gt>B<new>($xmldata)

Extends L<"new" in XML::Compile::Schema|XML::Compile::Schema/"new">.

=item $any-E<gt>B<get_type>($localname)

Get full namespace-qualified type from $localname.

=item $any-E<gt>B<get_elements>()

Get list of full namespace-qualified elements.

=item $any-E<gt>B<make_any_element_handler>($keyword)

Get appropriate CODEREF for translator registered as $keyword.

=item $any-E<gt>B<make_any_element_reader_handler>()

Get CODEREF for handling xs:any elements from a READER.

=item $any-E<gt>B<make_any_element_writer_handler>()

Get CODEREF for handling xs:any elements from a WRITER.

=item $any-E<gt>B<make_any_element_foreign_reader_handler>()

Get CODEREF for handling xs:any elements from a plugin READER.

=item $any-E<gt>B<make_any_element_foreign_writer_handler>()

Get CODEREF for handling xs:any elements from a plugin WRITER.

=back

=head1 TO DO

Possibly add additional translators.

=head1 BUGS

If an Any object is instantiated with conflicting schemas (for
example, different versions of the same schema), this module will
ignore any earlier versions whenever possible (during namespace
inferencing). However, under certain circumstances, it is possible it
will be confused.

=head1 COPYRIGHT

Same as Perl.

=head1 AUTHORS

Pedro Silva <psilva+git@pedrosilva.pt>

Philippe Bruhat (BooK) <book@cpan.org>

=cut
