use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'XML::SAX::Machines',
    VERSION_FROM  => 'lib/XML/SAX/Machines.pm',
    PREREQ_PM => {
       "XML::SAX"          => 0.05,
       "XML::SAX::Base"    => 1.02,  ## Need set_handler
       "XML::SAX::Writer"  => 0.39,  ## lotsa bugfixes.
    },
);


sub MY::libscan {
    package MY;
    my $self = shift;
    my ( $path ) = @_;
    return '' if /\.sw[a-z]$/;
    return '' unless length $self->SUPER::libscan( $path );
    return $path;
}

sub MY::install {
    package MY;
    my $self = shift ;
    my $install_rule = $self->SUPER::install( @_ );
    $install_rule =~ s/(^install :.*)/$1 install_site_config/m;
    return $install_rule;
}

## NOTE THE LITERAL TABS!!
sub MY::postamble { return <<'POSTAMBLE_END' }
install_site_config:
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) -I$(INST_LIB) -I$(INSTALLSITELIB) -MXML::SAX::Machines::ConfigHelper -we 'XML::SAX::Machines::ConfigHelper::_write_site_config_if_absent(shift)' $(INSTALLSITELIB)
POSTAMBLE_END
