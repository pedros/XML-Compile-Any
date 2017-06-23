package XML::Compile::Any::Translate::Reader::JSON;

use parent 'XML::Compile::Any::Translate::Reader';
use Carp ();
use JSON ();

sub _load {
    my $filename = shift or Carp::croak "Please provide \$filename";
    open my $fh, '<', $filename or Carp::croak "Cannot open $filename: $!";
    local $/ = undef;
    my $contents = <$fh>;
    close $fh;
    return JSON::decode_json($contents);
}

sub compile {
    return shift->SUPER::compile(
        @_,
        deserializer => \&_load
    );
}

1;
