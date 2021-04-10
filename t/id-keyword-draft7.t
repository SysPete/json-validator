use warnings;
use strict;

use JSON::Validator;
use Test::More;

my %json = (
  invalid_relative => '{"$id": "whatever"}',
  person           => '{
    "$id": "http://example.com/person.json",
    "definitions": {
      "Person": {
        "type": "object",
        "properties": {
          "firstName": { "type": "string" }
        }
      }
    }
  }'
);

my $jv = JSON::Validator->new;

eval { $jv->load_and_validate_schema($json{person}, {schema => 'http://json-schema.org/draft-07/schema#'}); };
ok !$@, "person json validates" or diag $@;
isa_ok $jv->schema, 'JSON::Validator::Schema::Draft7';

is $jv->schema->id,            'http://example.com/person.json',          'schema id';
is $jv->schema->moniker,       'draft07',                                 'moniker';
is $jv->schema->specification, 'http://json-schema.org/draft-07/schema#', 'schema specification';
is $jv->_id_key, '$id', 'detected id_key from draft-07';

eval { $jv->load_and_validate_schema($json{invalid_relative}, {schema => 'http://json-schema.org/draft-07/schema#'}); };
like $@, qr{cannot have a relative}, 'Root id cannot be relative' or diag $@;

done_testing;

