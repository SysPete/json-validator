package JSON::Validator::Schema::OpenAPIv2;
use Moo;
use MooX::TypeTiny;
extends 'JSON::Validator::Schema::Draft4';

use JSON::Validator::Util qw(E data_type negotiate_content_type schema_type);

my $X_RE = qr{^x-};

has '+errors' => (
    default => sub {
        my $self      = shift;
        my $validator = $self->new( %$self, allow_invalid_ref => 0 )
          ->resolve( $self->specification );
        return [ $validator->validate( $self->resolve->data ) ];
    },
);

has '+moniker' => (
    default => 'openapiv2',
);

has '+specification' => (
    default => 'http://swagger.io/v2/schema.json',
);

sub allow_invalid_ref {
    my $self = shift;
    return $self->{allow_invalid_ref} || 0 unless @_;

    delete $self->{errors};
    $self->{allow_invalid_ref} = shift;
    $self->data( $self->{data} ) if $self->{data};

    return $self;
}

sub _build_coerce {
    return { booleans => 1, numbers => 1, strings => 1 };
}

sub data {
    my $self = shift;
    return $self->{data} ||= {} unless @_;

    if ( $self->allow_invalid_ref ) {
        my $clone = $self->new( %$self, allow_invalid_ref => 0 );
        $self->{data} = $clone->data(shift)->bundle( { replace => 1 } )->data;
    }
    else {
        $self->{data} = $self->_resolve(shift);
    }

    delete $self->{errors};
    return $self;
}

sub parameters_for_request {
    my $self = shift;
    my ( $method, $path ) = ( lc $_[0][0], $_[0][1] );

    my $cache_key = "parameters_for_request:$method:$path";
    return $self->{cache}{$cache_key} if $self->{cache}{$cache_key};
    return undef unless $self->get( [ paths => $path, $method ] );

    my @accepts = map {@$_}
      $self->_find_all_nodes( [ paths => $path, $method ], 'consumes' );
    my @parameters = map {@$_}
      $self->_find_all_nodes( [ paths => $path, $method ], 'parameters' );
    for my $param (@parameters) {
        $param->{type} ||= schema_type( $param->{schema} || $param );
        $param->{accepts} = \@accepts if $param->{in} eq 'body';
    }

    return $self->{cache}{$cache_key} = \@parameters;
}

sub parameters_for_response {
    my $self = shift;
    my ( $method, $path, $status )
      = ( lc $_[0][0], $_[0][1], $_[0][2] || 200 );

    $status ||= 200;
    my $cache_key = "parameters_for_response:$method:$path:$status";
    return $self->{cache}{$cache_key} if $self->{cache}{$cache_key};

    my $responses = $self->get( [ paths => $path, $method, 'responses' ] );
    my $response  = $responses->{$status} || $responses->{default};
    return undef unless $response;

    my @parameters;
    if ( my $headers = $response->{headers} ) {
        push @parameters,
          map { +{ %{ $headers->{$_} }, in => 'header', name => $_ } }
          sort keys %$headers;
    }

    my @accepts
      = $self->_find_all_nodes( [ paths => $path, $method ], 'produces' );
    if ( exists $response->{schema} ) {
        push @parameters,
          {
            %$response, in => 'body', name => 'body',
            accepts => pop @accepts || []
          };
    }

    return $self->{cache}{$cache_key} = \@parameters;
}

sub routes {
    my $self = shift;

    my @sorted_paths = map { $_->[0] }
      sort { $a->[1] <=> $b->[1] || length $a->[0] <=> length $b->[0] }
      map { [ $_, /\{/ ? 1 : 0 ] }
      grep { $_ !~ $X_RE } keys %{ $self->get('/paths') || {} };

    my @operations;
    for my $path (@sorted_paths) {
        next unless my $methods = $self->get( [ paths => $path ] );
        for my $method ( sort keys %$methods ) {
            next if $method =~ $X_RE or $method eq 'parameters';
            push @operations,
              {
                method       => $method,
                operation_id => $methods->{$method}{operationId},
                path         => $path
              };
        }
    }

    return \@operations;
}

sub validate_request {
    my ( $self, $method_path, $req ) = @_;
    my $parameters = $self->parameters_for_request($method_path);

    my %get;
    for my $in (qw(body cookie formData header path query)) {
        $get{$in} = ref $req->{$in} eq 'CODE' ? $req->{$in} : sub {
            my ( $name, $param ) = @_;
            return { exists => exists $req->{$in}, value => $req->{$in} }
              unless defined $name;
            return {
                exists => exists $req->{$in}{$name},
                value  => $req->{$in}{$name}
            };
        };
    }

    return $self->_validate_request_or_response(
        request => $parameters,
        \%get
    );
}

sub validate_response {
    my ( $self, $method_path_status, $res ) = @_;
    my $parameters = $self->parameters_for_response($method_path_status);

    my %get;
    for my $in (qw(body cookie header)) {
        $get{$in} = ref $res->{$in} eq 'CODE' ? $res->{$in} : sub {
            my ( $name, $param ) = @_;
            return {
                exists => exists $res->{$in}{$name},
                value  => $res->{$in}{$name}
            };
        };
    }

    return $self->_validate_request_or_response(
        response => $parameters,
        \%get
    );
}

sub _build_formats {
    my $self = shift;

    return {
        'binary'    => sub {undef},
        'byte'      => JSON::Validator::Formats->can('check_byte'),
        'date'      => JSON::Validator::Formats->can('check_date'),
        'date-time' => JSON::Validator::Formats->can('check_date_time'),
        'double'    => JSON::Validator::Formats->can('check_double'),
        'email'     => JSON::Validator::Formats->can('check_email'),
        'float'     => JSON::Validator::Formats->can('check_float'),
        'hostname'  => JSON::Validator::Formats->can('check_hostname'),
        'int32'     => JSON::Validator::Formats->can('check_int32'),
        'int64'     => JSON::Validator::Formats->can('check_int64'),
        'ipv4'      => JSON::Validator::Formats->can('check_ipv4'),
        'ipv6'      => JSON::Validator::Formats->can('check_ipv6'),
        'password'  => sub {undef},
        'regex'     => JSON::Validator::Formats->can('check_regex'),
        'uri'       => JSON::Validator::Formats->can('check_uri'),
    };
}

sub _coerce_arrays {
    my ( $self, $val, $param ) = @_;
    my $data_type   = data_type $val->{value};
    my $schema_type = schema_type $param;
    return $val->{value} = [ $val->{value} ]
      if $schema_type eq 'array' and $data_type ne 'array';
    return $val->{value} = @{ $val->{value} } ? $val->{value}[-1] : undef
      if $schema_type ne 'array' and $data_type eq 'array';
}

sub _coerce_default_value {
    my ( $self, $val, $param ) = @_;

    if ( $param->{schema} and exists $param->{schema}{default} ) {
        @$val{qw(exists value)} = ( 1, $param->{schema}{default} );
    }
    elsif ( exists $param->{default} ) {
        @$val{qw(exists value)} = ( 1, $param->{default} );
    }
}

sub _coerce_parameter_format {
    my ( $self, $val, $param ) = @_;
    return unless $val->{exists};
    return unless my $format = $param->{collectionFormat};
    return $val->{value}
      = ref $val->{value} eq 'ARRAY' ? $val->{value} : [ $val->{value} ]
      if $format eq 'multi';
    return $val->{value} = [ split /\|/, $val->{value} ]
      if $format eq 'pipes';
    return $val->{value} = [ split /[ ]/, $val->{value} ] if $format eq 'ssv';
    return $val->{value} = [ split /\t/,  $val->{value} ] if $format eq 'tsv';
    return $val->{value} = [ split /,/,   $val->{value} ];
}

sub _definitions_path_for_ref {
    my ( $self, $ref ) = @_;
    if ( $ref->fqn =~ m!^.*#/(definitions|parameters|responses/.+)$! ) {
        my $path = $1;
        $path =~ s{/[^/]+$}{};
        return [ split /\//, $path ];
    }
    else {
        return ['definitions'];
    }
}

sub _find_all_nodes {
    my ( $self, $pointer, $leaf ) = @_;
    my @found;
    push @found, $self->data->{$leaf} if ref $self->data->{$leaf} eq 'ARRAY';

    my @path;
    for my $p (@$pointer) {
        push @path, $p;
        my $node = $self->get( [@path] );
        push @found, $node->{$leaf} if ref $node->{$leaf} eq 'ARRAY';
    }

    return @found;
}

sub _get_parameter_value {
    my ( $self, $param, $get ) = @_;
    my $val = $get->{ $param->{in} }->( $param->{name}, $param );
    @$val{qw(in name)} = ( @$param{qw(in name)} );
    return $val;
}

sub _prefix_error_path {
    return join '', "/$_[0]", $_[1] =~ /\w/ ? ( $_[1] ) : ();
}

sub _resolve_ref {
    my ( $self, $ref_url, $base_url, $root ) = @_;
    $ref_url = "#/definitions/$ref_url" if $ref_url =~ /^\w+$/;
    return $self->SUPER::_resolve_ref( $ref_url, $base_url, $root );
}

sub _validate_body {
    my ( $self, $direction, $val, $param ) = @_;
    $val->{content_type} = $param->{accepts}[0]
      if !$val->{content_type} and @{ $param->{accepts} };

    if ( $val->{accept} ) {
        $val->{content_type}
          = negotiate_content_type( $param->{accepts}, $val->{accept} );
        $val->{valid} = $val->{content_type} ? 1 : 0;
        return E "/header/Accept",
          [ join( ', ', @{ $param->{accepts} } ), type => $val->{accept} ]
          unless $val->{valid};
    }
    if ( @{ $param->{accepts} } and !$val->{content_type} ) {
        $val->{valid} = 0;
        return E "/$param->{name}",
          [ join( ', ', @{ $param->{accepts} } ) => type =>
              $val->{content_type} ];
    }
    if ( $param->{required} and !$val->{exists} ) {
        $val->{valid} = 0;
        return E "/$param->{name}", [qw(object required)];
    }
    if ( $val->{exists} ) {
        local $self->{"validate_$direction"} = 1;
        my @errors = map {
            $_->path( _prefix_error_path( $param->{name}, $_->path ) );
            $_
        } $self->validate( $val->{value}, $param->{schema} );
        $val->{valid} = @errors ? 0 : 1;
        return @errors;
    }

    return;
}

sub _validate_request_or_response {
    my ( $self, $direction, $parameters, $get ) = @_;

    my @errors;
    for my $param (@$parameters) {
        my $val = $self->_get_parameter_value( $param, $get );
        $self->_coerce_default_value( $val, $param ) unless $val->{exists};

        if ( $param->{in} eq 'body' ) {
            push @errors, $self->_validate_body( $direction, $val, $param );
            next;
        }

        $self->_coerce_parameter_format( $val, $param )
          if $direction eq 'request';

        if ( $val->{exists} ) {
            $self->_coerce_arrays( $val, $param );
            local $self->{"validate_$direction"} = 1;
            my @e = map {
                $_->path( _prefix_error_path( $param->{name}, $_->path ) );
                $_
            } $self->validate( $val->{value}, $param->{schema} || $param );
            push @errors, @e;
            $val->{valid} = @e ? 0 : 1;
        }
        elsif ( $param->{required} ) {
            push @errors, E "/$param->{name}", [qw(object required)];
            $val->{valid} = 0;
        }
    }

    return @errors;
}

sub _validate_type_file {
    my ( $self, $data, $path, $schema ) = @_;
    return
      unless $schema->{required}
      and ( not defined $data or not length $data );
    return E $path => 'Missing property.';
}

sub _validate_type_object {
    my ( $self, $data, $path, $schema ) = @_;
    return E $path, [ object => type => data_type $data]
      if ref $data ne 'HASH';
    return shift->SUPER::_validate_type_object(@_)
      unless $self->{validate_request};

    my ( @errors, %ro );
    for my $name ( keys %{ $schema->{properties} || {} } ) {
        next unless $schema->{properties}{$name}{readOnly};
        push @errors, E "$path/$name", "Read-only." if exists $data->{$name};
        $ro{$name} = 1;
    }

    local $schema->{required}
      = [ grep { !$ro{$_} } @{ $schema->{required} || [] } ];

    my $discriminator = $schema->{discriminator};
    if ( $discriminator and !$self->{inside_discriminator} ) {
        return E $path, "Discriminator $discriminator has no value."
          unless my $name = $data->{$discriminator};
        return E $path, "No definition for discriminator $name."
          unless my $dschema = $self->get("/definitions/$name");
        local $self->{inside_discriminator} = 1;    # prevent recursion
        return $self->_validate( $data, $path, $dschema );
    }

    return (
        @errors,
        $self->_validate_type_object_min_max( $_[1], $path, $schema ),
        $self->_validate_type_object_dependencies( $_[1], $path, $schema ),
        $self->_validate_type_object_properties( $_[1], $path, $schema ),
    );
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::Schema::OpenAPIv2 - OpenAPI version 2 / Swagger

=head1 SYNOPSIS

  use JSON::Validator;
  my $schema = JSON::Validator->new->schema("...")->schema;

  # Check for specification errors
  my $errors = $schema->errors;

  # Returns a list of zero or more JSON::Validator::Error objects
  my @request_errors = $schema->validate_request(
    [get => "/path"],
    {body => sub { return {exists => 1, value => {}} }},
  );

  # Returns a list of zero or more JSON::Validator::Error objects
  my @response_errors = $schema->validate_response(
    [get => "/path", 200],
    {body => sub { return {exists => 1, value => {}} }},
  );

=head1 DESCRIPTION

This class represents L<http://swagger.io/v2/schema.json>.

=head1 ATTRIBUTES

=head2 moniker

  $str    = $schema->moniker;
  $schema = $schema->moniker("openapiv2");

Used to get/set the moniker for the given schema. Default value is "openapiv2".

=head2 specification

  my $str    = $schema->specification;
  my $schema = $schema->specification($str);

Defaults to "L<http://swagger.io/v2/schema.json>".

=head1 METHODS

=head2 allow_invalid_ref

  $bool   = $schema->allow_invalid_ref;
  $schema = $schema->allow_invalid_ref(1);

Setting this to true will replace all C<$ref>s in the schema before validating
it. This can be useful if you have a complex schema that you want to split into
different files where OpenAPIv2 normally does not allow you to.

Setting this attribute will not work if the schema has recursive C<$ref>s.

This method is highly EXPERIMENTAL, and it is not advices to use this method.

=head2 coerce

  my $schema   = $schema->coerce({booleans => 1, numbers => 1, strings => 1});
  my $hash_ref = $schema->coerce;

Coercion is enabled by default, since headers, path parts, query parameters,
... are in most cases strings.

See also L<JSON::Validator/coerce>.

=head2 data

  my $hash_ref = $schema->data;
  my $schema   = $schema->data($bool);
  my $schema   = $schema->data($hash_ref);
  my $schema   = $schema->data($url);

Same as L</JSON::Validator::Schema/data>, but will bundle the schema if
L</allow_invalid_ref> is set.

=head2 new

  $schema = JSON::Validator::Schema::OpenAPIv2->new(\%attrs);
  $schema = JSON::Validator::Schema::OpenAPIv2->new;

Same as L<JSON::Validator::Schema/new>, but will also build L/coerce>.

=head2 parameters_for_request

  $parameters = $schema->parameters_for_request([$method, $path]);

Finds all the request parameters defined in the schema, including inherited
parameters. Returns C<undef> if the C<$path> and C<$method> cannot be found.

Example return value:

  [
    {in => "query", name => "q"},
    {in => "body", name => "body", accepts => ["application/json"]},
  ]

The return value MUST not be mutated.

=head2 parameters_for_response

  $array_ref = $schema->parameters_for_response([$method, $path, $status]);

Finds the response parameters defined in the schema. Returns C<undef> if the
C<$path>, C<$method> and C<$status> cannot be found. Will default to the
"default" response definition if C<$status> could not be found and "default"
exists.

Example return value:

  [
    {in => "header", name => "X-Foo"},
    {in => "body", name => "body", accepts => ["application/json"]},
  ]

The return value MUST not be mutated.

=head2 routes

  $collection = $schema->routes;

Used to gather all available routes in the schema and return them sorted. The
result is an array reference, where each item has a hash looking like
this:

  {
    method       => 'get',
    path         => '/user/{id}',
    operation_id => 'getUser', # Might be undef()
  }

=head2 validate_request

  @errors = $schema->validate_request([$method, $path], \%req);

This method can be used to validate a HTTP request. C<%req> should contain
key/value pairs representing the request parameters. Example:

  %req = (
    body => sub {
      my ($param_name, $param_for_request) = shift;
      return {exists => 1, value => \%all_params} unless defined $param_name;
      return {exists => 1, value => "..."};
    },
    formData => {email => "..."},
    header => {"X-Request-Base" => "..."},
    path => {id => "..."},
    query => {limit => 42},
  );

"formData", "header", "path" and "query" can be either a hash-ref, a hash-like
object or a code ref, while "body" MUST be a code ref. The return value from
the code ref will get mutated, making it possible to check if an individual
parameter was validated or not.

  # Before: "exists" and "value" must be present
  my @evaluated;
  $req{query} =  sub { push @evaluated, {exists => 1, value => 42}, return $evaluated[-1] };

  # Validate
  $schema->validate_request(get => "/user"], \%req);

  # After: "in", "name" and "valid" are added
  $evaluated[-1] ==> {exists => 1, value => 42, in => "query", name => "foo", valid => 1};

A plain hash-ref will I</not> get mutated.

The body hash-ref can also have a "content_type" key. This will be checked
against the list of valid request or response content types in the spec.

=head2 validate_response

  @errors = $schema->validate_response([$method, $path, $status], \%res);

This method can be used to validate a HTTP response. C<%res> should contain
key/value pairs representing the response parameters. Example:

  %res = (
    body => sub {
      my ($param_name, $param_for_response) = shift;
      return {exists => 1, value => \%all_params} unless defined $param_name;
      return {accept => "application/json", exists => 1, value => "..."};
    },
    header => {"Location" => "..."},
  );

C<%res> follows the same rules as C<%req> in L</validate_request>, but also
supports "accept", instead of specifying "content_type". "accept" should have
the same format as an "Accept" HTTP header.

=head1 SEE ALSO

L<JSON::Validator>, L<Mojolicious::Plugin::OpenAPI>,
L<http://openapi-specification-visual-documentation.apihandyman.io/>

=cut
