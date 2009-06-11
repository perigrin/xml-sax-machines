use inc::Module::Install;

perl_version '5.006001';
name 'XML-SAX-Machines';
all_from 'lib/XML/SAX/Machines';

requires 'XML::SAX' => 0.05;
requires 'XML::SAX::Base' => 1.02;
requires 'XML::SAX::Writer' => 0.42;

auto_set_repository;
auto_manifest;
auto_install;
WriteAll;
