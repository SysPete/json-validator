use warnings;
use strict;

use JSON::Validator;
use Path::Tiny;
use Test::More;

my $jv     = JSON::Validator->new;
my @errors = $jv->schema('data://main/spec.json')->validate({firstName => 'yikes!'});

is int(@errors), 1, 'one error';
is $errors[0]->path,    '/lastName',         'lastName';
is $errors[0]->message, 'Missing property.', 'required';
is_deeply $errors[0]->TO_JSON, {path => '/lastName', message => 'Missing property.'}, 'TO_JSON';

push @INC, path(__FILE__)->parent->child('stack')->stringify;
require Some::Module;

eval { Some->validate_age1({age => 1}) };
like $@, qr{age1\.json}, 'could not find age1.json';

ok !Some->validate_age0({age => 1}), 'validate_age0';
ok !Some::Module->validate_age0({age => 1}), 'validate_age0';
ok !Some::Module->validate_age1({age => 1}), 'validate_age1';

eval { MyPackage::TestX->validate('data:///spec.json', {}) };
ok !$@, 'found spec.json in main' or diag $@;

@errors = $jv->schema('data://main/spec.json')->validate({});
like "@errors", qr{firstName.*lastName}, 'required is sorted';

package MyPackage::TestX;
sub validate { $jv->schema($_[1])->validate($_[2]) }

package main;
is_deeply [sort keys %{$jv->store->schemas}], [qw(data:///spec.json data://main/spec.json)], 'schemas in store';

done_testing;

__DATA__
@@ spec.json

{
  "title": "Example Schema",
  "type": "object",
  "required": ["lastName", "firstName"],
  "properties": {
      "firstName": { "type": "string" },
      "lastName": { "type": "string" },
      "age": { "type": "integer", "minimum": 0, "description": "トシ" }
  }
}

