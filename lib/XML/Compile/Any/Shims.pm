package XML::Compile::Any::Schims;

use strict;
use warnings; no warnings 'redefine';
use Log::Report qw/xml-compile-oozie/;
use XML::Compile::Translate::Writer;

=pod

=over

=item B<makeAnyElement>()

Monkey-patch XML::Compile::Translate::Writer::makeAnyElement to
actually use an any_element CODEREF passed to the compile method in
XML::Compile::Schema;

=back

=cut

my $old_makeAnyElement = \&XML::Compile::Translate::Writer::makeAnyElement;
*XML::Compile::Translate::Writer::makeAnyElement = sub {
    my ($self, $path, $handler, $yes, $no, $process, $min, $max) = @_;
    my $any = $old_makeAnyElement->(@_);

    bless sub {
        my @elems = $any->(@_);
        my @result;
        while (@elems) {
            my ($type, $data) = (shift @elems, shift @elems);
            my ($label, $out) = $handler->($type, $data, $path, $self);
            push @result, $label, $out if defined $label;
        }
        @result;
    }, 'ANY';
};



1;
