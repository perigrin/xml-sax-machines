package XML::SAX::Machines::ConfigHelper;

=head1 NAME

XML::SAX::Machine::ConfigHelper - rarely needed config routines.

=head1 SYNOPSIS

    NONE: for internal use only.

=head1 DESCRIPTION

Some operations, like creating or writing XML::SAX::Machine::MyConfig.pm are
rarely needed, and take a few modules not normally needed by
XML::SAX::Machines.  So this module contains all that and prevents bloating
"normal" processes.  Read the source to see what I mean.

=cut

use strict;

## See the Makefile target "install_site_config" for where this is called.
sub _write_site_config_if_absent {
    my ( $install_site_lib ) = @_;

    eval "use Data::Dumper; 1" or die $@;
    if ( eval "require XML::SAX::Machines::SiteConfig; 1" ) {
        warn
           qq[***\n*** Not overwriting $INC{"XML/SAX/Machines/SiteConfig.pm"}\n***\n];
        return;
    }

    require File::Spec;
    my $dest = File::Spec->catfile(
        $install_site_lib, "XML", "SAX", "Machines", "SiteConfig.pm"
    );
    open OUT, ">$dest" or die "$!: $dest";
    warn "*** Writing $dest\n";
    print OUT <<'SITE_CONFIG_END';
package XML::SAX::Machines::SiteConfig;

#
# Which options are legal in ProcessorClassOptions.  This is provided here
# so you can extend the options if need be.  It's also a handy quick
# reference.  The master defaults are in DefaultConfig.pm.
#
$LegalProcessorClassOptions = {
#     ConstructWithOptionsHashes => "Use Foo->new( { Handler => $h } ) instead of Foo->new( Handler => $h )",
};
    

#
# SAX Processor specific configs.
#
# Per-processor options
# =====================
# 
# ConstructWithOptionsHashes (boolean)
#
#     tells XML::SAX::Machine to construct the processor like:
#
#        Foo->new(
#            { Handler => $h },
#        );
#
#    instead of
#
#        Foo->new( Handler => $h );
#

$ProcessorClassOptions = {
#     "XML::Filter::MyFilter" => {
#         ConstructWithOptionsHashes => 1,
#     },
};

1;
SITE_CONFIG_END
}

1;
