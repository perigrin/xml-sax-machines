package XML::SAX::Manifold;

=head1 NAME

XML::SAX::Manifold - Multipass processing of documents

=head1 SYNOPSIS

    use XML::SAX::Machines qw( Manifold ) ;

    my $m = Manifold(
        $channel0,
        $channel1,
        $channel2,
        {
            Handler => $h, ## optional
        }
    );

=head1 DESCRIPTION

XML::SAX::Manifold is a SAX machine that allows "multipass" processing
of a document by sending the document through several channels of SAX
processors one channel at a time.  A channel may be a single SAX
processor or a pipeline (see L<XML::SAX::Pipeline>).

The results of each channel are aggregated by a SAX filter that supports
the C<end_all> event, C<XML::Filter::Merger> by default.  See the
section on writing an aggregator and L<XML::Filter::Merger>.

This differs from L<XML::Filter::SAXT> in that the channels are
prioritized and each channel receives all events for a document before
the next channel receives any events.  XML::SAX::Manifold buffers all
events while feeding them to the highest priority channel
(C<$processor1> in the synopsis), and replays them for each lower
priority channel one at a time.

The event flow for the example in the SYNOPSIS would look like the
following, with the numbers next to the connection arrow indicating when
the document's events flow along that arrow.

   +--------------------------------------------------------+
   |         An XML::SAX::Manifold instance                 |
   |                                                        |
   |               +-----------+                            |
   |            +->| Channel_0 |-+                          |
   |          1/   +-----------+  \1                        |
   |  Intake  /                    \                        |
 1 |  +------+ 2   +-----------+  2 \    +--------+ Exhaust |   
 --+->| Dist |---->| Channel_1 |-----*-->| Merger |---------+--> $h
   |  +------+     +-----------+    /    +--------+         |
   |          \3                  3/                        |
   |           \   +-----------+  /                         |
   |            +->| Channel_2 |-+                          |
   |               +-----------+                            |
   +--------------------------------------------------------+

Here's the timing of the event flows:

   1: upstream -> Dist. -> Channel_0 -> Merger -> downstream
   2:             Dist. -> Channel_1 -> Merger -> downstream
   3:             Dist. -> Channel_2 -> Merger -> downstream

When the document arrives from upstream, the events all arrive during
time period 1 and are buffered and also passed through Channel_0 and
Channel_0's output is sent to the Merger.  After all events have been
received (as indicated by an C<end_document> event from upstream), all
events are then played back through Channel_1 and then through Channel_2
(which also output to the Merger).

It's the merger's job to assemble the three documents it receives in to
one document; see L<XML::Filter::Merger> for details.

=cut

use base qw( XML::SAX::Machine );

$VERSION = 0.1;

use strict;
use Carp;

=head1 METHODS

=over

=item new

    my $d = XML::SAX::Manifold->new( @channels, \%options );

Longhand for calling the Manifold function exported by XML::SAX::Machines.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my @options_hash_if_present = @_ && ref $_[-1] eq "HASH" ? pop : () ;

    my $channel_num = 0;

    my $self = $proto->SUPER::new(
        [ Intake => "XML::Filter::Distributor", (1..$#_+1) ],
        map( [ "Channel_" . $channel_num++ => $_ => qw( Merger ) ], @_ ),
        [ Merger => "XML::Filter::Merger" => qw( Exhaust ) ],
        @options_hash_if_present
    );

    my $distributor = $self->find_part( 0 );
    $distributor->set_aggregator( $self->find_part( -1 ) )
        if $distributor->can( "set_aggregator" );

    return $self;
}

=back

=head1 Writing an aggregator.

To be written.  Pretty much just that C<start_manifold_processing> and
C<end_manifold_processing> need to be provided.  See L<XML::Filter::Merger>
and it's source code for a starter.

=cut

1;
