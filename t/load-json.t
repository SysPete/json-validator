use warnings;
use strict;

use JSON::Validator;
use Path::Tiny;
use Test::More;

my $file   = path(__FILE__)->parent->child('spec', 'person.json');
my $jv     = JSON::Validator->new->schema($file);
my @errors = $jv->validate({firstName => 'yikes!'});

is int(@errors), 1, 'one error';
is $errors[0]->path,    '/lastName',         'lastName';
is $errors[0]->message, 'Missing property.', 'required';
is_deeply $errors[0]->TO_JSON, {path => '/lastName', message => 'Missing property.'}, 'TO_JSON';

my $spec = path($file)->slurp;
$spec =~ s!"#!"person.json#! or die "Invalid spec: $spec";
path("$file.2")->spew_utf8($spec);
ok eval { JSON::Validator->new->schema("$file.2") }, 'test issue #1 where $ref could not point to a file' or diag $@;
unlink "$file.2";

# load from cache
is(eval { JSON::Validator->new->schema('http://swagger.io/v2/schema.json'); 42 }, 42, 'loaded from cache') or diag $@;

like $jv->schema->id, qr{^file:.*person\.json}, 'schema id';
is_deeply [sort keys %{$jv->store->schemas}], [$jv->schema->id], 'schemas in store';

done_testing;
