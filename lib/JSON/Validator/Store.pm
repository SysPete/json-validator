package JSON::Validator::Store;

use Digest::MD5 'md5_hex';
use File::Spec;
use HTTP::Tiny;
use JSON::MaybeXS ();
use JSON::Validator::Util qw(data_section);
use Mojo::URL;
use Path::Tiny qw(cwd path);
use URI;
use URI::Escape qw(uri_unescape);

use constant BUNDLED_PATH =>
  path(__FILE__)->parent->child('cache')->stringify;
use constant CASE_TOLERANT => File::Spec->case_tolerant;

use Moo;
use MooX::TypeTiny;
with 'StackTrace::Auto';

has cache_paths => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        return [
            split( /:/, $ENV{JSON_VALIDATOR_CACHE_PATH} || '' ),
            BUNDLED_PATH
        ];
    },
);

has schemas => (
    is      => 'rw',
    default => sub { +{} },
);

has ua => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        return HTTP::Tiny->new(
            max_redirect => 3,
        );
    },
);

sub add {
    my ( $self, $id, $schema ) = @_;
    $id =~ s!(.)#$!$1!;
    $self->schemas->{$id} = $schema;
    return $id;
}

sub exists {
    my ( $self, $id ) = @_;
    return undef unless defined $id;
    $id =~ s!(.)#$!$1!;
    return $self->schemas->{$id} && $id;
}

sub get {
    my ( $self, $id ) = @_;
    return undef unless defined $id;
    $id =~ s!(.)#$!$1!;
    return $self->schemas->{$id};
}

sub load {
    my ( $self, $source ) = @_;
    return
         $self->_load_from_url($source)
      || $self->_load_from_data($source)
      || $self->_load_from_text($source)
      || $self->_load_from_file($source)
      || $self->get($source)
      || $self->_raise("Unable to load schema $source");
}

sub _load_from_data {
    my ( $self, $url, $id ) = @_;

    return undef unless $url =~ m!^data://([^/]*)/(.*)!;
    return $id if $id = $self->exists($url);

    my ( $class, $file ) = ( $1, $2 );    # data://([^/]*)/(.*)
    my $text = data_section $class, $file, { encoding => 'UTF-8' };
    $self->_raise("Could not find $url") unless $text;
    return $self->add( $url => $self->_parse($text) );
}

sub _load_from_file {
    my ( $self, $file ) = @_;

    $file =~ s!^file://!!;
    $file =~ s!#$!!;
    $file = $file ? path( uri_unescape($file) ) : cwd;
    return undef unless -e $file;

    $file = $file->realpath;

    my $id = URI->new( CASE_TOLERANT ? lc $file : "$file", 'file' );

# XXX Mojo::URL always prefixes with 'file:' but URI does not, and code elsewhere
# assumes the prefix will be in place
    $id =~ s{^/}{file:///};

    return $self->exists($id)
      || $self->add( $id => $self->_parse( $file->slurp_utf8 ) );
}

sub _load_from_text {
    my ( $self, $text ) = @_;
    my $is_scalar_ref = ref $text eq 'SCALAR';
    return undef unless $is_scalar_ref or $text =~ m!^\s*(?:---|\{)!s;

    my $id = sprintf 'urn:text:%s',
      md5_hex( $is_scalar_ref ? $$text : $text );
    return $self->exists($id)
      || $self->add(
        $id => $self->_parse( $is_scalar_ref ? $$text : $text ) );
}

sub _load_from_url {
    my ( $self, $url, $id ) = @_;

    return undef unless $url =~ m!^https?://!;
    return $id if $id = $self->exists($url);

    $url = Mojo::URL->new($url)->fragment(undef);
    return $id if $id = $self->exists($url);

    my $cache_path = $self->cache_paths->[0];
    my $cache_file = md5_hex("$url");
    for ( @{ $self->cache_paths } ) {
        my $path = path( $_, $cache_file );
        return $self->add( $url => $self->_parse( $path->slurp ) )
          if -r $path;
    }

    my $response = $self->ua->get($url);
    my $content;

    if ( $self->ua->isa("Mojo::UserAgent") ) {
        my $err = $response->error && $response->error->{message};
        $self->_raise($err) if $err;

        $content = $response->res->body;
    }
    else {
        # Assume HTTP::Tiny
        unless ( $response->{success} ) {
            $self->_raise( $response->{reason} );
        }
        $content = $response->{content};
    }

    if ( $cache_path and $cache_path ne BUNDLED_PATH and -w $cache_path ) {
        $cache_file = path( $cache_path, $cache_file );
        $cache_file->spew_utf8($content);
    }

    return $self->add( $url => $self->_parse($content) );
}

sub _parse {
    my ( $self, $json ) = @_;
    return JSON::MaybeXS::decode_json($json) if $json =~ m!^\s*\{!s;
    return JSON::Validator::Util::_yaml_load($json);
}

sub _raise { my $self = shift; die @_, $self->stack_trace->as_string }

1;

=encoding utf8

=head1 NAME

JSON::Validator::Store - Load and caching JSON schemas

=head1 SYNOPSIS

  use JSON::Validator;
  my $jv = JSON::Validator->new;
  $jv->store->add("urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f" => {...});
  $jv->store->load("http://api.example.com/my/schema.json");

=head1 DESCRIPTION

L<JSON::Validator::Store> is a class for loading and caching JSON-Schemas.

=head1 ATTRIBUTES

=head2 cache_paths

  my $store     = $store->cache_paths(\@paths);
  my $array_ref = $store->cache_paths;

A list of directories to where cached specifications are stored. Defaults to
C<JSON_VALIDATOR_CACHE_PATH> environment variable and the specs that is bundled
with this distribution.

C<JSON_VALIDATOR_CACHE_PATH> can be a list of directories, each separated by ":".

See L<JSON::Validator/Bundled specifications> for more details.

=head2 schemas

  my $hash_ref = $store->schemas;
  my $store = $store->schemas({});

Hold the schemas as data structures. The keys are schema "id".

=head2 ua

  my $ua    = $store->ua;
  my $store = $store->ua(Mojo::UserAgent->new);

Holds a L<HTTP::Tiny> or L<Mojo::UserAgent> object, used by L</schema> to load a
JSON schema from remote location.

The default L<HTTP::Tiny> will detect proxy settings from environment, and have
C<max_redirect> set to 3.

=head1 METHODS

=head2 add

  my $normalized_id = $store->add($id => \%schema);

Used to add a schema data structure. Note that C<$id> might not be the same as
C<$normalized_id>.

=head2 exists

  my $normalized_id = $store->exists($id);

Returns a C<$normalized_id> if it is present in the L</schemas>.

=head2 get

  my $schema = $store->get($normalized_id);

Used to retrieve a C<$schema> added by L</add> or L</load>.

=head2 load

  my $normalized_id = $store->load('https://...');
  my $normalized_id = $store->load('data://main/foo.json');
  my $normalized_id = $store->load('---\nid: yaml');
  my $normalized_id = $store->load('{"id":"yaml"}');
  my $normalized_id = $store->load(\$text);
  my $normalized_id = $store->load('/path/to/foo.json');
  my $normalized_id = $store->load('file:///path/to/foo.json');

Can load a C<$schema> from many different sources. The input can be a string or
a string-like object, and the L</load> method will try to resolve it in the
order listed in above.

Loading schemas from C<$text> will generate an C<$normalized_id> in L</schemas>
looking like "urn:text:$text_checksum". This might change in the future!

Loading files from disk will result in a C<$normalized_id> that always start
with "file://".

=head1 SEE ALSO

L<JSON::Validator>.

=cut
