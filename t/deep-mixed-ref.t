use warnings;
use strict;

use JSON::Validator;
use Path::Tiny;
use Test::More;

my $workdir = path(__FILE__)->parent->stringify;
my $file    = path($workdir, 'spec', 'with-deep-mixed-ref.json');
my $jv      = JSON::Validator->new(cache_paths => [])->schema($file);
my @errors  = $jv->validate({age => 1, weight => {mass => 72, unit => 'kg'}, height => 100});
is int(@errors), 0, 'valid input';

$file  = path($workdir, 'spec', 'with-relative-ref.json');
$jv = JSON::Validator->new(cache_paths => [])->schema($file);
@errors = $jv->validate({age => 'not a number'});
is int(@errors), 1, 'invalid age';

done_testing;
