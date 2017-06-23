package XML::Compile::Any::Translate::Writer::JSON;

use parent 'XML::Compile::Any::Translate::Writer';
use JSON ();

sub _dump {
    JSON->new->pretty->encode(@_);
}

sub compile {
    return shift->SUPER::compile(
        @_,
        serializer => \&_dump
    );
}

1;
