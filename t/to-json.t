use warnings;
use strict;

use JSON::MaybeXS 'JSON';
use JSON::Validator;
use Test::More;

my @errors = JSON::Validator->new->schema('data://main/error_object.json')
  ->validate(bless({path => '', message => 'yikes'}, 'JSON::Validator::Error'));
ok !@errors, 'TO_JSON on objects' or diag join ', ', @errors;

my $input = {
  errors => [JSON::Validator::Error->new('/', 'foo'), JSON::Validator::Error->new('/', 'bar')],
  valid  => JSON->false,
};
@errors = JSON::Validator->new->schema('data://main/error_array.json')->validate($input);
ok !@errors, 'TO_JSON on objects inside arrays' or diag join ', ', @errors;
is_deeply $input,
  {
  errors => [JSON::Validator::Error->new('/', 'foo'), JSON::Validator::Error->new('/', 'bar')],
  valid  => JSON->false,
  },
  'input objects are not changed';

done_testing;
__DATA__
@@ error_object.json
{
  "type": "object",
  "properties": { "message": { "type": "string" } },
  "required": ["message"]
}

@@ error_array.json
{
  "type": "object",
  "required": [ "errors" ],
  "properties": {
    "valid": { "type": "boolean" },
    "errors": {
      "type": "array",
      "items": {
        "type": "object",
        "required": [ "message" ],
        "properaties": {
          "message": { "type": "string" },
          "path": { "type": "string" }
        }
      }
    }
  }
}
