package XML::Compile::Any::Translate::Writer;

use Carp ();
use XML::Compile::Util;
use Data::Dumper;

use parent 'XML::Compile::Translate::Writer';

sub register {
    my ($self) = shift;
    $self->{ctx} = shift;
    $self->SUPER::register(@_);
}

sub make_any_element_foreign_writer_handler {
    my ($self) = @_;

   return sub {
        my ($type, $node) = @_;
        my $reader = $self->{ctx}->compile(READER => $type);
        my ($ns, $localname) = XML::Compile::Util::unpack_type($type);
        my $element;
        eval {
            $element = $reader->($node);
        } or Carp::carp "Couldn't parse this:\n$node" and return;
        return $localname, $element;
    }
}

sub compile {
    my ($self, $item, %args) = @_;
    my $handler = $args{any_element} or Carp::croak "need any_element parameter";
    my $serializer = $args{serializer} or Carp::croak "need serializer parameter";

    my $ret;
    $ret = sub {
        my ($root) = @_;

        return $root unless ref $root;

        if (ref $root eq 'HASH') {
            my %rename;
            while (my ($k, $v) = each %$root) {
                if (ref $v eq 'XML::LibXML::Element') {
                    my ($type, $node) = $handler->($k, $v);
                    $rename{$type} = [$k, $node];
                }
                else {
                    $ret->($v);
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

        return $serializer->($root);
    };
}

1;
