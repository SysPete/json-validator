use warnings;
use strict;

use JSON::Validator;
use Path::Tiny;
use Test::More;

eval { JSON::Validator->new->schema('data://main/spec.json') };
like $@, qr{Could not find.*/definitions/Pet"}, 'missing definition';

my $workdir = path(__FILE__)->parent->stringify;
eval { JSON::Validator->new->schema(path($workdir, 'spec', 'missing-ref.json')); };

ok $@, 'loading missing ref failed';
like $@, qr{Unable to load schema.*missing\.json}, 'error message' unless $^O eq 'MSWin32';

done_testing;

__DATA__
@@ spec.json
{
  "schema": {
    "type": "array",
    "items": { "$ref": "#/definitions/Pet" }
  }
}
