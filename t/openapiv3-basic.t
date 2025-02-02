use warnings;
use strict;

use JSON::Validator::Schema::OpenAPIv3;
use Path::Tiny;
use Test::Deep;
use Test::More;

my $cwd    = path(__FILE__)->parent;
my $schema = JSON::Validator::Schema::OpenAPIv3->new;
my ($body, $p, @errors);

subtest 'basic' => sub {
  is $schema->specification, 'https://spec.openapis.org/oas/3.0/schema/2019-04-02', 'specification';
  is_deeply $schema->coerce, {booleans => 1, numbers => 1, strings => 1}, 'default coercion';

  $schema = JSON::Validator->new->schema($cwd->child(qw(spec v3-petstore.json)))->schema;
  isa_ok $schema, 'JSON::Validator::Schema::OpenAPIv3';

  @errors = @{JSON::Validator->new->schema({openapi => '3.0.0', paths => {}})->schema->errors};
  is "@errors", '/info: Missing property.', 'invalid schema';

  is_deeply(
    $schema->routes,
    [
      {method => 'get',  operation_id => 'listPets',    path => '/pets'},
      {method => 'post', operation_id => 'createPets',  path => '/pets'},
      {method => 'get',  operation_id => 'showPetById', path => '/pets/{petId}'},
    ],
    'routes'
  );
};

subtest 'parameters_for_request' => sub {
  is $schema->parameters_for_request([GET => '/pets/nope']), undef, 'no such path';
  cmp_deeply $schema->parameters_for_request([GET => '/pets']), [superhashof({in => 'query', name => 'limit'})],
    'parameters_for_request inside path';

  cmp_deeply $schema->parameters_for_request([post => '/pets']),
    [
    superhashof({in => 'cookie', name => 'debug'}),
    superhashof({in => 'body',   name => 'body', accepts => [qw(application/json application/x-www-form-urlencoded)]})
    ],
    'parameters_for_request for body';
  cmp_deeply $schema->parameters_for_request([get => '/pets/{petId}']),
    [superhashof({in => 'path', name => 'petId'}), superhashof({in => 'query', name => 'wantAge'})],
    'parameters_for_request inside method';
};

subtest 'parameters_for_response' => sub {
  is $schema->parameters_for_response([GET => '/pets/nope']), undef, 'no such path';
  cmp_deeply $schema->parameters_for_response([GET => '/pets']),
    [
    superhashof({in => 'header', name => 'x-next'}),
    superhashof({in => 'body',   name => 'body', accepts => [qw(application/json application/xml)]}),
    ],
    'parameters_for_request inside path and default response code';
  cmp_deeply $schema->parameters_for_response([GET => '/pets', 404]),
    [superhashof({in => 'body', name => 'body', accepts => [qw(application/json application/xml)]})],
    'default response';
};

subtest 'validate_request' => sub {
  @errors = $schema->validate_request([get => '/pets'], {query => {limit => '10', foo => '42'}});
  is "@errors", '', 'limit ok, even as string';

  @errors = $schema->validate_request([get => '/pets'], {query => {limit => 'foo'}});
  is "@errors", '/limit: Expected integer - got string.', 'limit failed';

  $body   = {exists => 0};
  @errors = $schema->validate_request([POST => '/pets'], {body => \&body});
  is "@errors", '/body: Missing property.', 'default content type, but missing body';
  is_deeply $body, {content_type => 'application/json', exists => 0, in => 'body', name => 'body'}, 'input was mutated';

  $body   = {exists => 1, value => {name => 'kitty'}};
  @errors = $schema->validate_request([POST => '/pets'], {body => \&body});
  is "@errors", '/body/id: Missing property.', 'missing id in body';

  $body   = {exists => 1, value => {id => 42, name => 'kitty'}};
  @errors = $schema->validate_request([POST => '/pets'], {body => \&body});
  is "@errors", '', 'valid request body';
  is_deeply $body,
    {
    content_type => 'application/json',
    exists       => 1,
    in           => 'body',
    name         => 'body',
    valid        => 1,
    value        => $body->{value}
    },
    'input was mutated';
};

subtest 'validate_response' => sub {
  $body   = {exists => 1, value => {id => 42, name => 'kitty'}};
  @errors = $schema->validate_response([POST => '/pets', 201], {});
  is "@errors", '', 'valid response body 201';

  $body   = {exists => 1, value => {code => 42}};
  @errors = $schema->validate_response([post => '/pets', 200], {body => \&body});
  is "@errors", '/body/message: Missing property.', 'valid response body default';
};

subtest 'validate_response - accept' => sub {
  $body   = {accept => 'text/plain'};
  @errors = $schema->validate_response([get => '/pets'], {body => \&body});
  is "@errors", '/header/Accept: Expected application/json, application/xml - got text/plain.', 'invalid accept';
  is_deeply $body, {accept => 'text/plain', content_type => '', in => 'body', name => 'body', valid => 0},
    'failed to negotiate content type';

  $body   = {accept => 'application/*'};
  @errors = $schema->validate_response([get => '/pets'], {body => \&body});
  is "@errors", '', 'valid accept';
  is_deeply $body,
    {accept => 'application/*', content_type => 'application/json', in => 'body', name => 'body', valid => 1},
    'negotiated content type';
};

done_testing;

sub body {$body}
