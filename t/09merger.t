use strict;

use Test;
use XML::SAX::ParserFactory;
use XML::Filter::Merger;
use XML::SAX::Writer;
use UNIVERSAL;

my $p;
my $h;

my $out;

my @tests = (
sub {
    my $w = XML::SAX::Writer->new( Output => \$out );
    $h = XML::Filter::Merger->new( Handler => $w );
    $p = XML::SAX::ParserFactory->parser( Handler => $h );
    ok UNIVERSAL::isa( $h, "XML::Filter::Merger" );
},

##
## default (non-IncludeAllRoots) mode
##
sub {
    $out = "";
    $h->start_manifold_document( {} );
    $p->parse_string( "<foo1><bar /></foo1>" );
    $p->parse_string( "<foo2><baz /></foo2>" );
    $h->end_manifold_document( {} );
    $out =~ m{<foo1\s*><bar\s*/><baz\s*/></foo1\s*>}
        ? ok 1
        : ok $out, "something like <foo><bar /><baz /></foo>" ;
},


##
## default (IncludeAllRoots) mode
##
sub {
    $out = "";
    $h->set_include_all_roots( 1 );
    $h->start_manifold_document( {} );
    $p->parse_string( "<foo1><bar /></foo1>" );
    $p->parse_string( "<foo2><baz /></foo2>" );
    $h->end_manifold_document( {} );
    $out =~ m{<foo1\s*><bar\s*/><foo2\s*><baz\s*/></foo2\s*></foo1\s*>}
        ? ok 1
        : ok $out, "something like <foo1><bar /><foo2><baz /></foo2></foo1>" ;
},


);

plan tests => scalar @tests;

$_->() for @tests;
