package XML::Compile::Any::Translate::Writer::YAML;

use parent 'XML::Compile::Any::Translate::Writer';
use YAML ();

sub compile {
    return shift->SUPER::compile(
        @_,
        serializer => \&YAML::Dump
    );
}

1;
