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

Combines several documents in to one "manifold" document.  This is done
by defining two non-SAX events--C<start_manifold_document> and
C<end_manifold_document>--that are called before the first document to be
combined and after the last one, respectively.

The first full document to be started after the
C<start_manifold_document> is the master document and is emitted as-is
except that it will contain the contents of all of the other documents.

Unlike a normal SAX filter, however, documents may be inserted by
issuing a C<start_document> ... C<end_document> event sequence inside
the root element of the master document.  The bodies of such documents
are inserted inline in the master document without the root element or
events before/after the root element.  The root element may be inserted
by calling C<set_include_all_roots> with a true value.  This is how the
L<ByRecord|XML::SAX::ByRecord> SAX machine works, and is as though an
XInclude directive had been placed in the master document at the point
where the secondary document's events were received.

Additionally, any documents received after the master document's
C<end_document> and before the C<end_manifold_document> are inserted
just before the master document's root C<end_element>.  To accomplish
this, the master document's root C<end_element> and all remaining events
are buffered and only forwarded when the C<end_manifold_document> is
received.

=head1 DETAILED DESCRIPTION

In case the above was a bit vague, here are the rules this filter lives
by.

For the master document:

=over

=item *

Events before the root C<end_element> are forwarded as received.
Because of the rules for secondary documents, any secondary documents
sent to the filter in the midst of a master document will be
inserted inline as their events are received.


=item *

All remaining events, from the root C<end_element> are
buffered until the end_manifold_document() received, and are then
forwarded on.

=back

For secondary documents:

=over

=item *

All events before the root C<start_element> are discarded.  There is
no way to recover these (though we can add an option for most non-DTD
events, I believe).

=item *

The root C<start_element> is discarded by default, or forwarded if
C<set_include_all_roots( $v )> has been used to set a true value.

=item *

All events up to, but not including, the root C<end_element> are
forwarded as received.

=item *

The root C<end_element> is discarded or forwarded if the matching
C<start_element> was.

=item *

All remaining events until and including the C<end_document> are
forwarded and processing.

=item *

Secondary documents may contain other secondary documents.

=item *

Secondary documents need not be well formed.  The must, however, be well
balanced.

=back

This requires very little buffering and is "most natural" with the
limitations:

=over

=item *

All of each secondary document's events must all be received
between two consecutive events of it's master document.  This is because
most master document events are not buffered and this filter cannot
tell from which upstream source a document came.

=item *

If the master document should happen to have some egregiously large
amount of whitespace, commentary, or illegal events after the root
element, buffer memory could be huge.  This should be exceedingly rare,
even non-existent in the real world.

=item *

If any documents are not well balanced, the result won't be.

=item *

=back

=head1 LIMITATIONS

The events before and after a secondary document's root element events
are discarded.  It is conceivable that characters, PIs and commentary
outside the root element might need to be kept.  This may be added as an
option.

The DocumentLocators are not properly managed: they should be saved and
restored around each each secondary document.

If either of these bite you, contact me.

=cut

use base qw( XML::SAX::Base );

$VERSION = 0.2;

use strict;
use Carp;
use XML::SAX::EventMethodMaker qw( sax_event_names compile_missing_methods );

sub _logging() { 0 };

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
    $self->{DocumentDepth}           = 0;
    $self->{DocumentCount}           = 0;
    $self->{TailEvents}              = undef;
    $self->{ManifoldDocumentStarted} = 1;
    $self->{Cutting}                 = 0;
    $self->{Depth}                   = 0;
    $self->{RootEltSeen}             = 0;

## A little fudging here until XML::SAX::Base gets a new release
$self->{Methods} = {};
}


sub _log {
    my $self = shift;

    warn "MERGER: ",
        $self->{DocumentCount}, " ",
        "| " x $self->{DocumentDepth},
        ". " x $self->{Depth},
        @_,
        "\n";
}


sub _cutting {
    my $self = shift;

#    if ( @_ ) {
#        my $v = shift;
#warn "MERGER: CUTTING ", $v ? "SET!!" : "CLEARED!!", "\n"
#   if ( $v && ! $self->{Cutting} ) || ( ! $v && $self->{Cutting} );
#        $self->{Cutting} = $v;
#    }

    my $v = shift;

    $v = 1
        if ! defined $v
            && ( $self->{DocumentCount} > 1
               || $self->{DocumentDepth} > 1
            )
            && ! $self->{Depth};


    $self->_log(
        $v ? () : "NOT ",
        "CUTTING ",
        do { my $c = (caller(1))[3]; $c =~ s/.*:://; $c }, 
        " (doccount=$self->{DocumentCount}",
        " docdepth=$self->{DocumentDepth}",
        " depth=$self->{Depth})"
    ) if _logging;
    return $v;

    return $self->{Cutting};
}


sub _saving {
    my $self = shift;

    return
        $self->{DocumentCount} == 1
        && $self->{DocumentDepth} == 1
        && $self->{RootEltSeen};
}


sub _push {
    my $self = shift;

    $self->_log( "SAVING ", $_[0] ) if _logging;

    push @{$self->{TailEvents}}, [ @_ ];

    return undef;
}


sub start_document {
    my $self = shift;

    warn "start_document received without a start_manifold_document"
        unless $self->{ManifoldDocumentStarted};

    push @{$self->{DepthStack}}, $self->{Depth};

    ++$self->{DocumentCount} unless $self->{DocumentDepth};
    ++$self->{DocumentDepth};
    $self->{Depth} = 0;

    $self->SUPER::start_document( @_ )
        unless $self->_cutting;

}

sub end_document {
    my $self = shift;

    $self->_push( "end_document", @_ )
        unless $self->_cutting;

    --$self->{DocumentDepth};
    $self->{Depth} = pop @{$self->{DepthStack}};
}


sub start_element {
    my $self = shift ;

    my $r;

    $r = $self->SUPER::start_element( @_ )
        unless $self->_cutting( $self->{IncludeAllRoots} ? 0 : () );

    ++$self->{Depth};

    return $r;
}


sub end_element {
    my $self = shift ;

    --$self->{Depth};
    $self->{RootEltSeen} ||= $self->{DocumentDepth} == 1 && $self->{Depth} == 0;

    return undef if $self->_cutting( $self->{IncludeAllRoots} ? 0 : () );

    return $self->_saving
        ? $self->_push( "end_element", @_ )
        : $self->SUPER::end_element( @_ );
}

compile_missing_methods __PACKAGE__, <<'TEMPLATE_END', sax_event_names;
sub <EVENT> {
    my $self = shift;

    return undef if $self->_cutting;

    return $self->_saving
        ? $self->_push( "<EVENT>", @_ )
        : $self->SUPER::<EVENT>( @_ );
}
TEMPLATE_END



=item end_manifold_document

This must be called after the last document's end_document is called.  It
is passed an empty ({}) data structure which is passed on to the
next processor's end_document() call.  This call also causes the
end_element() for the root element to be passed on.

=cut

sub end_manifold_document {
    my $self = shift;

    my $r;
    if ( $self->{TailEvents} ) {
	for ( @{$self->{TailEvents}} ) {
	    my $sub_name = shift @$_;
            $self->_log( "PLAYING BACK $sub_name" ) if _logging;
            $sub_name = "SUPER::$sub_name";
	    $r = $self->$sub_name( @$_ );
	}
    }
    $self->{ManifoldDocumentStarted} = 0;
    return $r;
}

=item set_include_all_roots

    $h->set_include_all_roots( 1 );

Setting this option causes the merger to include all root element nodes,
not just the first document's.  This means that later documents are
treated as subdocuments of the output document, rather than as envelopes
carrying subdocuments.

Given two documents received are:

 Doc1:   <root1><foo></root1>

 Doc1:   <root2><bar></root2>

 Doc3:   <root3><baz></root3>

then with this option cleared (the default), the result looks like:

    <root1><foo><bar><baz></root1>

.  This is useful when processing document oriented XML and each
upstream filter channel gets a complete copy of the document.  This is
the case with the machine L<XML::SAX::Manifold> and the splitting filter
L<XML::Filter::Distributor>.

With this option set, the result looks like:

    <root1><foo><root2><bar></root2><root3><baz></root3></root1>

This is useful when processing record oriented XML, where the first
document only contains the preamble and postamble for the records and
not all of the records.  This is the case with the machine
L<XML::SAX::ByRecord> and the splitting filter
L<XML::Filter::DocSplitter>.

The two splitter filters mentioned set this feature appropriately.

=cut

sub set_include_all_roots {
    my $self = shift;
    $self->{IncludeAllRoots} = shift;
}

=back

=head1 BUGS

Does not yet buffer all events after the first document's root end_element
event.

=head1 AUTHOR

    Barrie Slaymaker <barries@slaysys.com>

=head1 COPYRIGHT

    Copyright 2002, Barrie Slaymaker, All Rights Reserved.

You may use this module under the terms of the Artistic, GNU Public, or
BSD licenses, you choice.

=cut

1;
