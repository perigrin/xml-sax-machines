package XML::Filter::Merger;

=head1 NAME

XML::Filter::Merger - Assemble multiple SAX streams in to one document

=head1 SYNOPSIS

    ## See XML::SAX::Manifold and XML::SAX::Pipeline for easy ways
    ## to use this processor.  XML::SAX::Manifold uses this
    ## processor to implement multipass document processing, for
    ## instance.

    my $w = XML::SAX::Writer->new(           Output => \*STDOUT );
    my $h = XML::Filter::Merger->new(           Handler => $w );
    my $p = XML::SAX::ParserFactory->parser( Handler => $h );

    $h->start_manifold_document( {} );
    $p->parse_file( $_ ) for @ARGV;
    $h->end_manifold_document( {} );
        

=head1 DESCRIPTION

Combines several documents in to one.  Here's how:

The first document received after the call to start_manifold_document()
is emitted all the way up to it's closing root element tag.  This tag
and all text, comments, PIs, etc. following it are buffered, as is the
end_document event.

Each additional document is stripped of everything up to and including
its root element start_element event and from the root element
end_element  event through the end_document event.  All events between
the root element start_element and end_element events are stripped.

When the end_manifold_document() method is called, the events that were
buffered from the first document are then emitted, resulting in a well
formed XML document that has the guts from each of the input documents
sandwiched between the head and tail of the first document.

TODO: Allow a lot of customization, like how deep to cut the roots off
of each document (it just cuts down to and including the root element
now), and allow some "glue" to be wrapped around each document and
between documents.

=cut

use base qw( XML::SAX::Base );

$VERSION = 0.1;

use strict;
use Carp;

=head1 METHODS

=over

=item new

    my $d = XML::Filter::Merger->new( \%options );

=cut

=item start_manifold_document

This must be called before the first document's start_document arrives.

It is passed an empty ({}) data structure, which is passed on to the
handler's start_document.

=cut

sub start_manifold_document {
    my $self = shift;
    $self->{DocumentCount} = 0;
    $self->{RootEndEltData} = undef;
    $self->{Depth} = 0;
    $self->{ManifoldDocumentStarted} = 1;

## A little fudging here until XML::SAX::Base gets a new release
$self->{Methods} = {};

    $self->SUPER::start_document( @_ );
}


sub start_document {
    my $self = shift;
    warn "start_document received without a start_manifold_document"
        unless $self->{ManifoldDocumentStarted};
    ++$self->{DocumentCount};
    ## Consume these.
}

sub end_document {
    my $self = shift;
}


sub start_element {
    my $self = shift ;

    return $self->SUPER::start_element( @_ )
        if $self->{Depth}++ || $self->{DocumentCount} == 1;

    return undef ;
}


sub end_element {
    my $self = shift ;

    $self->{RootEndEltData} = [ @_ ]
        if ! --$self->{Depth} && $self->{DocumentCount} == 1;

    return $self->SUPER::end_element( @_ )
        if $self->{Depth} ;


    return undef ;
}


=item end_manifold_document

This must be called after the last document's end_document is called.  It
is passed an empty ({}) data structure which is passed on to the
next processor's end_document() call.  This call also causes the
end_element() for the root element to be passed on.

=cut

sub end_manifold_document {
    my $self = shift;
    $self->end_element( @{$self->{RootEndEltData}} );
    $self->{ManifoldDocumentStarted} = 0;
    return $self->SUPER::end_document( @_ );
}

=back

=head1 AUTHOR

    Barrie Slaymaker <barries@slaysys.com>

=head1 COPYRIGHT

    Copyright 2002, Barrie Slaymaker, All Rights Reserved.

You may use this module under the terms of the Artistic, GNU Public, or
BSD licenses, you choice.

=cut

1;
