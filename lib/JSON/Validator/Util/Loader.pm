package JSON::Validator::Util::Loader;
use strict;
use warnings;

use Carp;
use Exporter qw(import);
use MIME::Base64 qw(decode_base64);
use Path::Tiny;

our @EXPORT_OK = qw(data_section);

my (%BIN, %CACHE);

sub data_section { $_[0] ? $_[1] ? _all($_[0])->{$_[1]} : _all($_[0]) : undef }

sub _all {
  my $class = shift;

  return $CACHE{$class} if $CACHE{$class};
  local $.;
  my $handle = do { no strict 'refs'; \*{"${class}::DATA"} };
  return {} unless fileno $handle;
  seek $handle, 0, 0;
  my $data = join '', <$handle>;

  # Ignore everything before __DATA__ (some versions seek to start of file)
  $data =~ s/^.*\n__DATA__\r?\n/\n/s;

  # Ignore everything after __END__
  $data =~ s/\n__END__\r?\n.*$/\n/s;

  # Split files
  (undef, my @files) = split /^@@\s*(.+?)\s*\r?\n/m, $data;

  # Find data
  my $all = $CACHE{$class} = {};
  while (@files) {
    my ($name, $data) = splice @files, 0, 2;
    $all->{$name} = $name =~ s/\s*\(\s*base64\s*\)$// && ++$BIN{$class}{$name} ? b64_decode $data : $data;
  }

  return $all;
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Util::Loader - Load from __DATA__

=head1 DESCRIPTION

Original code extracted from L<Mojo::Loader>.

Allows multiple files to be stored in the C<DATA> section of a class, which can
then be accessed individually.

  package Foo;

  1;
  __DATA__

  @@ test.txt
  This is the first file.

  @@ test2.html (base64)
  VGhpcyBpcyB0aGUgc2Vjb25kIGZpbGUu

  @@ test
  This is the
  third file.

Each file has a header starting with C<@@>, followed by the file name and optional
instructions for decoding its content. Currently only the Base64 encoding is
supported, which can be quite convenient for the storage of binary data.

=head1 FUNCTIONS

Implements the following functions, which can be imported individually.

=head2 data_section

  my $all   = data_section 'Foo::Bar';
  my $index = data_section 'Foo::Bar', 'index.html';

Extract embedded file from the C<DATA> section of a class, all files will be cached once they have been accessed for
the first time.

  # List embedded files
  say for keys %{data_section 'Foo::Bar'};

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Loader>, L<https://mojolicious.org>.

=cut
