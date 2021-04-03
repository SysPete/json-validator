package JSON::Validator::Path;

use overload '@{}' => sub { shift->parts }, bool => sub {1}, '""' => sub { shift->to_string }, fallback => 1;

use Encode qw(decode);
use URI::Escape qw(uri_escape uri_unescape);

use Moo;
use namespace::clean;

has charset => (
  is      => 'rw',
  default => 'UTF-8',
);

sub canonicalize {
  my $self = shift;

  my $parts = $self->parts;
  for (my $i = 0; $i <= $#$parts;) {
    if    (!length $parts->[$i] || $parts->[$i] eq '.' || $parts->[$i] eq '...') { splice @$parts, $i, 1 }
    elsif ($i < 1 || $parts->[$i] ne '..' || $parts->[$i - 1] eq '..')           { $i++ }
    else                                                                         { splice @$parts, --$i, 2 }
  }

  return @$parts ? $self : $self->trailing_slash(undef);
}

sub clone {
  my $self = shift;

  my $clone = $self->new;
  if (exists $self->{charset}) { $clone->{charset} = $self->{charset} }
  if (my $parts = $self->{parts}) {
    $clone->{$_} = $self->{$_} for qw(leading_slash trailing_slash);
    $clone->{parts} = [@$parts];
  }
  else { $clone->{path} = $self->{path} }

  return $clone;
}

sub contains { $_[1] eq '/' || $_[0]->to_route =~ m!^\Q$_[1]\E(?:/|$)! }

sub leading_slash { shift->_parse(leading_slash => @_) }

sub merge {
  my ($self, $path) = @_;

  # Replace
  return $self->parse($path) if $path =~ m!^/!;

  # Merge
  pop @{$self->parts} unless $self->trailing_slash;
  $path = $self->new($path);
  push @{$self->parts}, @{$path->parts};
  return $self->trailing_slash($path->trailing_slash);
}

around new => sub {
  my ( $orig, $class, @args ) = @_;
  @_ > 1 ? $class->$orig->parse(@args) : $class->$orig;
};

sub parse {
  my $self = shift;
  $self->{path} = shift;
  delete @$self{qw(leading_slash parts trailing_slash)};
  return $self;
}

sub parts { shift->_parse(parts => @_) }

sub to_abs_string {
  my $path = shift->to_string;
  return $path =~ m!^/! ? $path : "/$path";
}

sub to_dir {
  my $clone = shift->clone;
  pop @{$clone->parts} unless $clone->trailing_slash;
  return $clone->trailing_slash(!!@{$clone->parts});
}

sub to_route {
  my $clone = shift->clone;
  return '/' . join '/', @{$clone->parts}, $clone->trailing_slash ? '' : ();
}

sub to_string {
  my $self = shift;

  # Path
  my $charset = $self->charset;
  if (defined(my $path = $self->{path})) {
    $path = encode( $charset, $path ) if $charset;
    return uri_escape( $path, '^A-Za-z0-9\-._~!$&\'()*+,;=%:@/' );
  }

  # Build path
  my @parts = @{$self->parts};
  @parts = map { encode($charset, $_ ) } @parts if $charset;
  my $path = join '/', map { uri_escape( $_, '^A-Za-z0-9\-._~!$&\'()*+,;=:@' ) } @parts;
  $path = "/$path" if $self->leading_slash;
  $path = "$path/" if $self->trailing_slash;
  return $path;
}

sub trailing_slash { shift->_parse(trailing_slash => @_) }

sub _parse {
  my ($self, $name) = (shift, shift);

  unless ($self->{parts}) {
    my $path    = uri_unescape( delete($self->{path}) // '' );
    my $charset = $self->charset;
    $path                   = decode($charset, $path) // $path if $charset;
    $self->{leading_slash}  = $path =~ s!^/!!;
    $self->{trailing_slash} = $path =~ s!/$!!;
    $self->{parts}          = [split /\//, $path, -1];
  }

  return $self->{$name} unless @_;
  $self->{$name} = shift;
  return $self;
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Path - Path

=head1 SYNOPSIS

  use JSON::Validator::Path;

  # Parse
  my $path = JSON::Validator::Path->new('/foo%2Fbar%3B/baz.html');
  say $path->[0];

  # Build
  my $path = JSON::Validator::Path->new('/i/♥');
  push @$path, 'mojolicious';
  say "$path";

=head1 DESCRIPTION

A port to L<Moo> of L<Moo::Path>.

B<NOTE:> this is a TEMPORARY solution which allows code that used to use
L<Mojo::Path> to continue to work without any modification.

L<JSON::Validator::Path> is a container for paths used by L<Mojo::URL>, based on L<RFC 3986|https://tools.ietf.org/html/rfc3986>.

=head1 ATTRIBUTES

L<JSON::Validator::Path> implements the following attributes.

=head2 charset

  my $charset = $path->charset;
  $path       = $path->charset('UTF-8');

Charset used for encoding and decoding, defaults to C<UTF-8>.

  # Disable encoding and decoding
  $path->charset(undef);

=head1 METHODS

=head2 canonicalize

  $path = $path->canonicalize;

Canonicalize path by resolving C<.> and C<..>, in addition C<...> will be treated as C<.> to protect from path
traversal attacks.

  # "/foo/baz"
  JSON::Validator::Path->new('/foo/./bar/../baz')->canonicalize;

  # "/../baz"
  JSON::Validator::Path->new('/foo/../bar/../../baz')->canonicalize;

  # "/foo/bar"
  JSON::Validator::Path->new('/foo/.../bar')->canonicalize;

=head2 clone

  my $clone = $path->clone;

Return a new L<JSON::Validator::Path> object cloned from this path.

=head2 contains

  my $bool = $path->contains('/i/♥/mojolicious');

Check if path contains given prefix.

  # True
  JSON::Validator::Path->new('/foo/bar')->contains('/');
  JSON::Validator::Path->new('/foo/bar')->contains('/foo');
  JSON::Validator::Path->new('/foo/bar')->contains('/foo/bar');

  # False
  JSON::Validator::Path->new('/foo/bar')->contains('/f');
  JSON::Validator::Path->new('/foo/bar')->contains('/bar');
  JSON::Validator::Path->new('/foo/bar')->contains('/whatever');

=head2 leading_slash

  my $bool = $path->leading_slash;
  $path    = $path->leading_slash($bool);

Path has a leading slash. Note that this method will normalize the path and that C<%2F> will be treated as C</> for
security reasons.

  # "/foo/bar"
  JSON::Validator::Path->new('foo/bar')->leading_slash(1);

  # "foo/bar"
  JSON::Validator::Path->new('/foo/bar')->leading_slash(0);

=head2 merge

  $path = $path->merge('/foo/bar');
  $path = $path->merge('foo/bar');
  $path = $path->merge(JSON::Validator::Path->new);

Merge paths. Note that this method will normalize both paths if necessary and that C<%2F> will be treated as C</> for
security reasons.

  # "/baz/yada"
  JSON::Validator::Path->new('/foo/bar')->merge('/baz/yada');

  # "/foo/baz/yada"
  JSON::Validator::Path->new('/foo/bar')->merge('baz/yada');

  # "/foo/bar/baz/yada"
  JSON::Validator::Path->new('/foo/bar/')->merge('baz/yada');

=head2 new

  my $path = JSON::Validator::Path->new;
  my $path = JSON::Validator::Path->new('/foo%2Fbar%3B/baz.html');

Construct a new L<JSON::Validator::Path> object and L</"parse"> path if necessary.

=head2 parse

  $path = $path->parse('/foo%2Fbar%3B/baz.html');

Parse path.

=head2 to_abs_string

  my $str = $path->to_abs_string;

Turn path into an absolute string.

  # "/i/%E2%99%A5/mojolicious"
  JSON::Validator::Path->new('/i/%E2%99%A5/mojolicious')->to_abs_string;
  JSON::Validator::Path->new('i/%E2%99%A5/mojolicious')->to_abs_string;

=head2 parts

  my $parts = $path->parts;
  $path     = $path->parts([qw(foo bar baz)]);

The path parts. Note that this method will normalize the path and that C<%2F> will be treated as C</> for security
reasons.

  # Part with slash
  push @{$path->parts}, 'foo/bar';

=head2 to_dir

  my $dir = $route->to_dir;

Clone path and remove everything after the right-most slash.

  # "/i/%E2%99%A5/"
  JSON::Validator::Path->new('/i/%E2%99%A5/mojolicious')->to_dir->to_abs_string;

  # "i/%E2%99%A5/"
  JSON::Validator::Path->new('i/%E2%99%A5/mojolicious')->to_dir->to_abs_string;

=head2 to_route

  my $route = $path->to_route;

Turn path into a route.

  # "/i/♥/mojolicious"
  JSON::Validator::Path->new('/i/%E2%99%A5/mojolicious')->to_route;
  JSON::Validator::Path->new('i/%E2%99%A5/mojolicious')->to_route;

=head2 to_string

  my $str = $path->to_string;

Turn path into a string.

  # "/i/%E2%99%A5/mojolicious"
  JSON::Validator::Path->new('/i/%E2%99%A5/mojolicious')->to_string;

  # "i/%E2%99%A5/mojolicious"
  JSON::Validator::Path->new('i/%E2%99%A5/mojolicious')->to_string;

=head2 trailing_slash

  my $bool = $path->trailing_slash;
  $path    = $path->trailing_slash($bool);

Path has a trailing slash. Note that this method will normalize the path and that C<%2F> will be treated as C</> for
security reasons.

  # "/foo/bar/"
  JSON::Validator::Path->new('/foo/bar')->trailing_slash(1);

  # "/foo/bar"
  JSON::Validator::Path->new('/foo/bar/')->trailing_slash(0);

=head1 OPERATORS

L<JSON::Validator::Path> overloads the following operators.

=head2 array

  my @parts = @$path;

Alias for L</"parts">. Note that this will normalize the path and that C<%2F> will be treated as C</> for security
reasons.

  say $path->[0];
  say for @$path;

=head2 bool

  my $bool = !!$path;

Always true.

=head2 stringify

  my $str = "$path";

Alias for L</"to_string">.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
