use strict;

use Test;
use XML::SAX::Machines qw( Machine );

my $m;

my $out;

my @tests = (
sub {
    $out = "";
    $m = Machine(
         [ Intake => "XML::Filter::Distributor" => qw( A B ) ],
            [ A => "XML::SAX::Base" => qw( Merger ) ],
            [ B => "XML::SAX::Base" => qw( Merger ) ],
        [ Merger => "XML::Filter::Merger" => qw( Output ) ],
        [ Output => \$out ],
    );
    $m->Intake->set_aggregator( $m->Merger );
    ok $m->isa( "XML::SAX::Machine" );
},

sub {
    $out = "";
    ok $m->parse_string( "<foo><bar /></foo>" );
},

sub {
    $out =~ m{<foo\s*><bar\s*/><bar\s*/></foo\s*>}
        ? ok 1
        : ok $out, "something like <foo><bar /></foo>" ;
},
);

plan tests => scalar @tests;

$_->() for @tests;
