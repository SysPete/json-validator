#!/usr/bin/env perl

# vim: ft=perl

requires 'Carp';
requires 'Class::Method::Modifiers' => '1.05';    # install_modifier
requires 'Digest::MD5';
requires 'Digest::SHA';
requires 'HTTP::Tiny';
requires 'JSON::MaybeXS';
requires 'JSON::Pointer';
requires 'MIME::Base64';
requires 'Moo' => '2.000000';
requires 'namespace::clean';
requires 'Path::Tiny';
requires 'Sub::HandlesVia';
requires 'Sub::Install';
requires 'Throwable';
requires 'Type::Tiny';
requires 'URI';

suggests 'Data::Validate::Domain';
suggests 'Data::Validate::IP';
suggests 'Sereal' => '4.00';
suggests 'Net::IDN::Encode';

on 'test' => sub {
    required 'Test::Deep';
    required 'Test::Exception';
    required 'Test::More';
    suggests 'Test::JSON::Schema::Acceptance';
    suggests 'Test2::Tools::Compare';
    suggests 'YAML::PP';
};
