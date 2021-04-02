#!/usr/bin/env perl

# vim: ft=perl

requires 'Digest::SHA';
requires 'JSON::MaybeXS';

suggests 'Data::Validate::Domain';
suggests 'Data::Validate::IP';
suggests 'Net::IDN::Encode';

on 'test' => sub {
  suggests 'Test::JSON::Schema::Acceptance';
  suggests 'YAML::PP';
};
