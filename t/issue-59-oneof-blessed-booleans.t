use warnings;
use strict;

use JSON::Validator;
use JSON::MaybeXS 'JSON';
use Test::More;

my $jv     = JSON::Validator->new->schema('data://main/spec.json');
my @errors = $jv->validate({prop1 => JSON->false, prop2 => JSON->false});
is "@errors", '', 'oneof blessed booleans';

done_testing;

__DATA__

@@ spec.json
{
  "type": "object",
  "properties": {
    "prop1": {
      "$ref": "data://main/defs.json#/definitions/item"
    },
    "prop2": {
      "$ref": "data://main/defs.json#/definitions/item"
    }
  }
}

@@ defs.json
{
  "definitions": {
    "item": {
      "oneOf": [
        {"type": "object"},
        {"type": "boolean"}
      ]
    }
  }
}
