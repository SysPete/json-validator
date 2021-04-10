use lib '.';
use t::Helper;
use Path::Tiny;

my $file = path(__FILE__)->parent->child('spec', 'with-relative-ref.json');
my $jv   = jv;
$jv->cache_paths([]);
validate_ok {age => -1}, $file->stringify, E('/age', '-1 < minimum(0)');

done_testing;
