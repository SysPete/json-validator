use warnings;
use strict;

use File::Spec;
use JSON::Validator;
use Path::Tiny;
use URI::file;
use Test::More;

my $file = path(qw(t spec person.json))->absolute->stringify;
my $spec = URI::file->new($file);
my $jv   = JSON::Validator->new;
my $id   = File::Spec->case_tolerant ? lc $spec : $spec->as_string;

note $spec->as_string;
ok eval { $jv->schema($file) }, 'loaded from file://' or diag $@;
isa_ok $jv->schema, 'JSON::Validator::Schema';
is $jv->schema->get('/title'), 'Example Schema', 'got example schema';
is $jv->schema->id, $id, 'schema id';
is_deeply [sort keys %{$jv->store->schemas}], [$jv->schema->id], 'schemas in store';

ok eval { $jv->schema($spec->as_string) }, 'loaded from file:// again' or diag $@;
is $jv->schema->id, $id, 'schema id again';
is_deeply [sort keys %{$jv->store->schemas}], [$jv->schema->id], 'schemas in store again';

eval { $jv->load_and_validate_schema('no-such-file.json') };
like $@, qr{Unable to load schema no-such-file\.json}, 'cannot load no-such-file.json';

done_testing;
