use Mojo::Base -strict;
use JSON::Validator;
use JSON::MaybeXS 'JSON';
use Test::More;

my $encoder = JSON->new->utf8->allow_nonref;
my $jv      = JSON::Validator->new;
my %coerce  = (booleans => 1);
is_deeply($jv->coerce(%coerce)->coerce,  {booleans => 1}, 'hash is accepted');
is_deeply($jv->coerce(\%coerce)->coerce, {booleans => 1}, 'hash reference is accepted');

note 'make sure input is coerced';
is_deeply($jv->coerce('booleans,numbers,strings')->coerce, {%coerce, numbers => 1, strings => 1}, '1 is accepted');
my @items = ([boolean => 'true'], [integer => '42'], [number => '4.2']);
for my $i (@items) {
  for my $schema (schemas($i->[0])) {
    my $x = $i->[1];
    $jv->validate($x, $schema);
    is $encoder->allow_nonref->encode($x), $i->[1], sprintf 'no quotes around %s %s', $i->[0], $encoder->encode($schema);

    $x = {v => $i->[1]};
    $jv->validate($x, {type => 'object', properties => {v => $schema}});
    is $encoder->encode($x->{v}), $i->[1], sprintf 'no quotes around %s %s', $i->[0], $encoder->encode($schema);

    $x = [$i->[1]];
    $jv->validate($x, {type => 'array', items => $schema});
    is $encoder->encode($x->[0]), $i->[1], sprintf 'no quotes around %s %s', $i->[0], $encoder->encode($schema);
  }
}

done_testing;

sub schemas {
  my $base = {type => shift};
  return (
    $base,
    {type  => ['array', $base->{type}]},
    {allOf => [$base]},
    {anyOf => [{type => 'array'}, $base]},
    {oneOf => [$base,             {type => 'array'}]},
  );
}
