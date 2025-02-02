use warnings;
use strict;

use JSON::MaybeXS 'decode_json';
use Path::Tiny;
use Test::More;

use JSON::Validator;

my $draft07 = path(qw(lib JSON Validator cache 4a31fe43be9e23ca9eb8d9e9faba8892));
plan skip_all => "Cannot open $draft07" unless -r $draft07;

my $schema = decode_json($draft07->slurp);
my @errors = JSON::Validator->new->validate($schema, $schema);
ok !@errors, "validated draft07" or map { diag $_ } @errors;

done_testing;
