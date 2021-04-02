use Mojo::Base -strict;
use JSON::Validator;
use JSON::MaybeXS 'JSON';
use Test::More;

my $jv = JSON::Validator->new(coerce => 'defaults');
is_deeply($jv->coerce, {defaults => 1}, 'coerce defaults');

$jv->coerce('def');
is_deeply($jv->coerce, {defaults => 1}, 'coerce def');

$jv->schema({
  type        => 'object',
  definitions => {subscribed_to => {type => 'array', default => []}},
  properties =>
    {tos => {type => 'boolean', default => JSON->false}, subscribed_to => {'$ref' => '#/definitions/subscribed_to'}},
});

my $data   = {};
my @errors = $jv->validate($data);
is_deeply \@errors, [], 'defaults pass validation';
is_deeply $data, {tos => JSON->false, subscribed_to => []}, 'data was mutated';

$data->{tos} = JSON->true;
@errors = $jv->validate($data);
is_deeply $data, {tos => JSON->true, subscribed_to => []}, 'only subscribed_to was mutated';

$jv->schema({type => 'object', properties => {age => {type => 'number', default => 'invalid'}}});

@errors = $jv->validate({});
is $errors[0]->message, 'Expected number - got string.', 'default values must be valid';

done_testing;
