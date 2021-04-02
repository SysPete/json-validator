use lib '.';
use t::Helper;

use JSON::MaybeXS 'JSON';

my $encoder = JSON->new->utf8->allow_nonref;

sub j { $encoder->decode($encoder->encode($_[0])); }

my $schema = {type => 'object', properties => {v => {type => 'boolean'}}};

validate_ok {v => '0'},     $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => 'false'}, $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => 1},       $schema, E('/v', 'Expected boolean - got number.');
validate_ok {v => 0.5},     $schema, E('/v', 'Expected boolean - got number.');
validate_ok {v => JSON->true},  $schema;
validate_ok {v => JSON->false}, $schema;

validate_ok {v => JSON->true}, $schema;
validate_ok {v => 1000},     $schema, E('/v', 'Expected boolean - got number.');
validate_ok {v => 0.5},      $schema, E('/v', 'Expected boolean - got number.');
validate_ok {v => 'active'}, $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => bless({}, 'BoolTestOk')}, $schema;
validate_ok {v => bless({}, 'BoolTestFail')}, $schema, E('/v', 'Expected boolean - got BoolTestFail.');

validate_ok j(JSON->false), {type => 'boolean'};
validate_ok j(JSON->true),  {type => 'boolean'};
validate_ok j('foo'), {type => 'boolean'}, E('/', 'Expected boolean - got string.');
validate_ok undef, {properties => {}}, E('/', 'Expected object - got null.');

note 'boolean const';
my $bool_constant_false = {type => 'boolean', const => JSON->false};
my $bool_constant_true  = {type => 'boolean', const => JSON->true};
validate_ok JSON->false, $bool_constant_false;
validate_ok JSON->true,  $bool_constant_false, E('/', q{Does not match const: false.});
validate_ok JSON->true,  $bool_constant_true;
validate_ok JSON->false, $bool_constant_true, E('/', q{Does not match const: true.});

note 'boolean objects';
my $data = jv->store->get(jv->store->load(\"---\nv: true\n"));
isa_ok($data->{v}, 'JSON::PP::Boolean');
validate_ok $data, $schema;

SKIP: {
  skip 'boolean not installed', 1 unless eval 'require boolean;1';
  validate_ok {type => 'boolean'}, {type => 'object', properties => {type => {type => 'string'}}};
}

note 'coerce check data';
jv->coerce('bool');
coerce_ok({v => !!1},     $schema);
coerce_ok({v => !!0},     $schema);
coerce_ok({v => 0},       $schema);
coerce_ok({v => ''},      $schema);
coerce_ok({v => 'false'}, $schema);
coerce_ok({v => 'true'},  $schema);
coerce_ok({v => 1},       $schema);
coerce_ok({v => '1'},     $schema);

note 'coerce fail';
jv->coerce('booleans');
validate_ok {v => 0.5},      $schema, E('/v', 'Expected boolean - got number.');
validate_ok {v => -1},       $schema, E('/v', 'Expected boolean - got number.');
validate_ok {v => 'yessir'}, $schema, E('/v', 'Expected boolean - got string.');
validate_ok {v => 'nope'},   $schema, E('/v', 'Expected boolean - got string.');

note 'coerce const';
validate_ok 0, $bool_constant_false;
validate_ok 1, $bool_constant_false, E('/', q{Does not match const: false.});
validate_ok 1, $bool_constant_true;
validate_ok 0, $bool_constant_true, E('/', q{Does not match const: true.});

note 'ref';
my $ref = tie my %ref, 'JSON::Validator::Ref', JSON->true, '#/definitions/true';
ok exists $ref{'$ref'}, 'exists ref ref';
ok !exists $ref{foo},   'exists ref foo';
is $ref{'$ref'}, '#/definitions/true', 'value ref ref';
is $ref{'$ref'}, $ref->ref, 'tied ref ref';
is $ref{foo}, undef, 'value ref foo';
is $ref->schema, JSON->true, 'ref schema';
is int(%ref), 1, 'tied numeric';
is_deeply [keys %ref], ['$ref'], 'tied keys';
is_deeply [each %ref], ['$ref', '#/definitions/true'], 'tied each';

done_testing;

sub coerce_ok {
  my ($data, $schema) = @_;
  my $exp = {v => !$data->{v} || $data->{v} eq 'false' ? JSON->false : JSON->true};

  validate_ok $data, $schema;
  is_deeply $data, $exp, 'data was coerced correctly';
}

package BoolTestOk;
use overload '""' => sub {1};

package BoolTestFail;
use overload '""' => sub {2};
