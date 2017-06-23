package XML::Compile::Any::Translate::Reader;

use Carp ();
use XML::Compile::Util;
use Data::Dumper;

use parent 'XML::Compile::Translate::Reader';

sub register {
    my ($self) = shift;
    $self->{ctx} = shift;
    $self->SUPER::register(@_);
}

sub make_any_element_foreign_reader_handler {
    my ($self) = @_;

    return sub {
        my ($localname, $node, $item) = @_;
        my $type = $self->{ctx}->get_type($localname);

        return @_ unless $type;

        # ignore types in the same namespace as we're currently reading
        my ($item_ns) = XML::Compile::Util::unpack_type($item);
        my ($type_ns) = XML::Compile::Util::unpack_type($type);
        return @_ unless $item_ns ne $type_ns;

        my $writer = $self->{ctx}->compile(
            WRITER => $type,
            use_default_namespace => 1,
        );
        my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
        my $xml = $writer->($doc, $node);

        return $type, $xml;
    }
}

sub compile {
    my ($self, $item, %args) = @_;
    my $handler = $args{any_element} or Carp::croak "need any_element parameter";
    my $deserializer = $args{deserializer} or Carp::croak "need deserializer parameter";

    my $loaded = 0;
    my $ret;
    $ret = sub {
        my ($root) = @_;

        $root = $deserializer->($root) unless $loaded;

        return $root unless ref $root;

        if (ref $root eq 'HASH') {
            my %rename;
            while (my ($k, $v) = each %$root) {
                my ($type, $node) = $handler->($k, $v, $item);
                if ($type) {
                    $rename{$type} = [$k, $node];
                }
                else {
                    $ret->($root->{$k});
                }
            }
            while (my ($k, $v) = each %rename) {
                my ($old_key, $data) = @$v;
                delete $root->{$old_key};
                $root->{$k} = $data;
            }
        }
        elsif (ref $root eq 'ARRAY') {
            $ret->($_) for @$root;
        }
        elsif (ref $root eq 'SCALAR') {
            $ret->($$_);
        }
        elsif (ref $root eq 'CODE') {
            $root->();
        }
        else {
            Carp::croak "Don't understand type of object $root: " . ref $root;
        }

        return $root;
    };
}

1;
