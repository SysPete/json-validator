use warnings;
use strict;

use JSON::Validator;
use Test::More;

my $schema = JSON::Validator->new->schema('data://main/spec.json')->schema;
my @errors;

@errors = $schema->validate_request([get => '/pets/{id}'], {path => {id => 'a'}});
is "@errors", "/id: String is too short: 1/3.", 'invalid id';

@errors = $schema->validate_request([get => '/pets/{id}'], {path => {}});
is "@errors", "", 'default id';

my $id  = {};
my %req = (path => sub {$id});
@errors = $schema->validate_request([get => '/pets/{id}'], \%req);
is_deeply $id, {exists => 1, in => 'path', name => 'id', valid => 1, value => 'foo'}, 'input was mutated';
is "@errors", "", 'default id';
is $id->{value}, 'foo', 'coerced default value';

done_testing;

__DATA__
@@ spec.json
{
  "openapi": "3.0.0",
  "info": { "title": "Style And Explode", "version": "" },
  "paths": {
    "/pets/{id}": {
      "get": {
        "parameters": [
          {
            "name": "id",
            "in": "path",
            "required": true,
            "schema": {"type": "string", "default": "foo", "minLength": 3}
          }
        ],
        "responses" : {
          "200": {
            "description": "pet response",
            "schema": {"type": "object"}
          }
        }
      }
    }
  }
}
