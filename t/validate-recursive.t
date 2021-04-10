use warnings;
use strict;

use JSON::Validator;
use Test::More;

my $jv = JSON::Validator->new->schema('data://main/spec.json');

my @cases = (
  {name => "missing top-level property fails", json => {}, error => "/person: Missing property.",},
  {name => "top-level property OK", json => {person => {name => 'superwoman'}},},
  {
    name => "top-level property and child property OK",
    json => {person => {name => 'superwoman', children => [{name => 'batboy'}]}},
  },
  {
    name  => "top-level propety with bad child property fails",
    json  => {person => {name => 'superwoman', children => [{}]}},
    error => "/person/children/0/name: Missing property.",
  }
);

for my $case (@cases) {
  subtest $case->{name} => sub {
    my @errors = $jv->validate($case->{json});
    if ($case->{error}) {
      is @errors, 1, "... and we have one error";
      is $errors[0]->to_string, $case->{error}, "... and error is as expected";
    }
    else {
      ok !@errors, "... and we have no errors";
    }
  };
}

done_testing;
__DATA__
@@ spec.json
{
  "type": "object",
  "properties": {
    "person": {
      "$ref": "#/definitions/person"
    }
  },
  "required": [
    "person"
  ],
  "definitions": {
    "person": {
      "type": "object",
      "required": [ "name" ],
      "properties": {
        "name": {
          "type": "string"
        },
        "children": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/person"
          }
        }
      }
    }
  }
}
