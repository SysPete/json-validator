#!/usr/bin/env perl

# vim: ft=perl

requires 'Digest::SHA';
requires 'JSON::MaybeXS';
requires 'Moo' => '2.000000';
requires 'namespace::clean';

suggests 'Data::Validate::Domain';
suggests 'Data::Validate::IP';
suggests 'Net::IDN::Encode';

on 'test' => sub {
  suggests 'Test::JSON::Schema::Acceptance';
  suggests 'YAML::PP';
};
