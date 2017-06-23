package XML::Compile::Any::Translate::Reader::YAML;

use parent 'XML::Compile::Any::Translate::Reader';
use YAML ();

sub compile {
    return shift->SUPER::compile(
        @_,
        deserializer => sub {-f $_[0] ? YAML::LoadFile($_[0]) : YAML::Load($_[0])}
    );
}

1;
