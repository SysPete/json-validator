package t::Helper;
use warnings;
use strict;

use Class::Method::Modifiers qw(install_modifier);
use HTTP::Tiny;
use JSON::MaybeXS 'JSON';
use JSON::Pointer;
use JSON::Validator;
use Path::Tiny;
use Sub::Install;
use Test::More;

$ENV{TEST_VALIDATOR_CLASS} = 'JSON::Validator';

my $encoder = JSON->new->utf8->allow_blessed->allow_nonref->canonical->convert_blessed;

sub acceptance {
  my ($class, $schema_class, %acceptance_params) = @_;

  Test::More::plan(skip_all => 'cpanm Test::JSON::Schema::Acceptance')
    unless eval 'use Test::JSON::Schema::Acceptance 1.000 ();1';
  Test::More::plan(skip_all => 'cpanm Test2::Tools::Compare') unless eval 'use Test2::Tools::Compare 0.0001 ();1';
  Test::More::plan(skip_all => $@)                            unless eval "require $schema_class;1";

  my $test = sub { +{file => $_[0], group_description => $_[1], test_description => $_[2]} };
  my $ua   = _acceptance_ua($schema_class);

  $acceptance_params{todo_tests} = [map { $test->(@$_) } @{$acceptance_params{todo_tests}}]
    if $acceptance_params{todo_tests};

  my $specification = $schema_class =~ m!::(\w+)$! ? lc $1 : 'unknown';
  $specification = 'draft2019-09' if $specification eq 'draft201909';
  Test::JSON::Schema::Acceptance->new(specification => $specification)->acceptance(
    tests => $test->(split '/', $ENV{TEST_ACCEPTANCE} || ''),
    %acceptance_params,
    validate_data => sub {
      # original data for comparison
      my ($schema_p, $data_p) = @_;

      # args passed to validator can be mutated, so clone original args
      my ($schema_d, $data_d) = map { clone($_) } ($schema_p, $data_p);

      my $schema = $schema_class->new($schema_d, ua => $ua);
      return 0 if @{$schema->errors};

      my @errors = $schema->validate($data_d);

      # Doing internal tests on mutation, since I think Test::JSON::Schema::Acceptance is a bit too strict
      Test2::Tools::Compare::is($encoder->encode($data_d),   $encoder->encode($data_p),   'data structure is the same');
      Test2::Tools::Compare::is($encoder->encode($schema_d), $encoder->encode($schema_p), 'schema structure is the same')
        unless _skip_schema_is($schema_p);

      return @errors ? 0 : 1;
    },
  );
}

sub clone {
  return $encoder->decode($encoder->encode($_[0]));
}

sub edj {
  return $encoder->decode($encoder->encode(@_));
}

sub joi_ok {
  my ($data, $joi, @expected) = @_;
  my $description ||= @expected ? "errors: @expected" : "valid: " . $encoder->encode($data);
  my @errors = JSON::Validator::Joi->new($joi)->validate($data);
  Test::More::is_deeply([map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected], $description)
    or Test::More::diag($encoder->encode(\@errors));
}

my $jv_obj;
sub jv { $jv_obj ||= $ENV{TEST_VALIDATOR_CLASS}->new }

my $schema;
sub schema { $schema = $_[1] if $_[1]; $schema }

sub schema_validate_ok {
  my ($data, $schema, @expected) = @_;
  my $description = @expected ? "errors: @expected" : "valid: " . $encoder->encode($data);

  my @errors = t::Helper->schema->resolve($schema)->validate($data);
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  Test::More::is_deeply([map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected], $description)
    or Test::More::diag($encoder->encode(\@errors));
}

sub test {
  my ($class, $category, @methods) = @_;
  my $test_class = "t::test::$category";
  eval "require $test_class;1" or die $@;
  subtest "$category $_", sub { $test_class->$_ }
    for @methods;
}

sub validate_ok {
  my ($data, $schema, @expected) = @_;
  my $description = @expected ? "errors: @expected" : "valid: " . $encoder->encode($data);
  my @errors      = jv()->schema($schema)->validate($data);
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  Test::More::is_deeply([map { $_->TO_JSON } sort { $a->path cmp $b->path } @errors],
    [map { $_->TO_JSON } sort { $a->path cmp $b->path } @expected], $description)
    or Test::More::diag($encoder->encode(\@errors));
}

sub import {
  my $class  = shift;
  my $caller = caller;

  eval "package $caller; use Test::Deep; use Test::More; 1" or die $@;
  $_->import for qw(strict warnings);
  feature->import(':5.10');

  monkey_patch($caller => E                  => \&JSON::Validator::E);
  monkey_patch($caller => done_testing       => \&Test::More::done_testing);
  monkey_patch($caller => edj                => \&edj);
  monkey_patch($caller => false              => \&JSON::MaybeXS::false);
  monkey_patch($caller => joi_ok             => \&joi_ok);
  monkey_patch($caller => jv                 => \&jv);
  monkey_patch($caller => schema_validate_ok => \&schema_validate_ok);
  monkey_patch($caller => true               => \&JSON::MaybeXS::true);
  monkey_patch($caller => validate_ok        => \&validate_ok);
}

sub monkey_patch {
  my ( $into, $as, $code ) = @_;
  Sub::Install::install_sub(
    {
      into => $into,
      as   => $as,
      code => $code,
    }
  );
}

sub _acceptance_ua {
  my $schema_class = shift;
  my $ua = HTTP::Tiny->new;

  install_modifier 'HTTP::Tiny', 'around', 'request', sub {
      my ( $orig, $self, $method, $url, $args ) = @_;
      if ( $url =~ m{^https?://localhost:1234/(.+)$} ) {
          my $schema = path(qw(t spec remotes), $1)->slurp_utf8;
          return {
              success => 1,
              url     => $url,
              status  => 200,
              content => $schema,
          };
      }
      else {
          $self->$orig( $method, $url, $args );
      }
  };

  return $ua;
}

sub _skip_schema_is {
  my $data  = shift;
  my @paths = ('', '/properties/foo');

  # The URL has been changed by _acceptance_ua()
  return 1 if $encoder->encode($data) =~ m!localhost:1234!;

  # JSON::Validator always normalizes $ref with multiple keys
  for my $path (@paths) {
    my $ref = JSON::Pointer->get($data, $path);
    return 1 if ref $ref eq 'HASH' && $ref->{'$ref'} && 1 != keys %$ref;
  }

  return 0;
}

1;
