package HTTP::Engine::Request;
use Moose;
with 'MooseX::Object::Pluggable';

use Carp;
use HTTP::Headers;
use HTTP::Engine::Types::Core qw( Uri );
use HTTP::Engine::Types::Request qw( Header );
use IO::Socket qw[AF_INET inet_aton];

# the IP address of the client
has address => (
    is  => 'rw',
    isa => 'Str',
);

has context => (
    is      => 'rw',
    isa     => 'HTTP::Engine::Context',
    weakref => 1,
);

has cookies => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has method => (
    is  => 'rw',
    # isa => 'Str',
);

has protocol => (
    is  => 'rw',
    # isa => 'Str',
);

has query_parameters => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

# https or not?
has secure => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has uri => (
    is  => 'rw',
    isa => 'Uri',
    coerce => 1,
);

has user => ( is => 'rw', );

has raw_body => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

has headers => (
    is      => 'rw',
    isa     => 'Header',
    coerce  => 1,
    default => sub { HTTP::Headers->new },
    handles => [ qw(content_encoding content_length content_type header referer user_agent) ],
);

# Contains the URI base. This will always have a trailing slash.
# If your application was queried with the URI C<http://localhost:3000/some/path> then C<base> is C<http://localhost:3000/>.
has base => (
    is      => 'rw',
    isa     => 'URI',
    trigger => sub {
        my $self = shift;

        if ( $self->uri ) {
            $self->path; # clear cache.
        }
    },
);

has hostname => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->context->env->{REMOTE_HOST} || gethostbyaddr( inet_aton( $self->address ), AF_INET );
    },
);

# aliases
*body_params  = \&body_parameters;
*input        = \&body;
*params       = \&parameters;
*query_params = \&query_parameters;
*path_info    = \&path;

sub body {
    my ($self, $body) = @_;
    return $self->{_body}->body;
}

sub body_parameters {
    my ($self, $params) = @_;
    $self->{body_parameters} = $params if $params;
    return $self->{body_parameters};
}

sub cookie {
    my $self = shift;

    return keys %{ $self->cookies } if @_ == 0;

    if (@_ == 1) {
        my $name = shift;
        return undef unless exists $self->cookies->{$name}; ## no critic.
        return $self->cookies->{$name};
    }
}

sub param {
    my $self = shift;

    return keys %{ $self->parameters } if @_ == 0;

    if (@_ == 1) {
        my $param = shift;
        return wantarray ? () : undef unless exists $self->parameters->{$param};

        if ( ref $self->parameters->{$param} eq 'ARRAY' ) {
            return (wantarray)
              ? @{ $self->parameters->{$param} }
                  : $self->parameters->{$param}->[0];
        } else {
            return (wantarray)
              ? ( $self->parameters->{$param} )
                  : $self->parameters->{$param};
        }
    } elsif (@_ > 1) {
        my $field = shift;
        $self->parameters->{$field} = [@_];
    }
}

has parameters => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

sub path {
    my ($self, $params) = @_;

    if ($params) {
        $self->uri->path($params);
    } else {
        return $self->{path} if $self->{path};
    }

    my $path     = $self->uri->path;
    my $location = $self->base->path;
    $path =~ s/^(\Q$location\E)?//;
    $path =~ s/^\///;
    $self->{path} = $path;

    return $path;
}

sub upload {
    my $self = shift;

    return keys %{ $self->uploads } if @_ == 0;

    if (@_ == 1) {
        my $upload = shift;
        return wantarray ? () : undef unless exists $self->uploads->{$upload};

        if (ref $self->uploads->{$upload} eq 'ARRAY') {
            return (wantarray)
              ? @{ $self->uploads->{$upload} }
          : $self->uploads->{$upload}->[0];
        } else {
            return (wantarray)
              ? ( $self->uploads->{$upload} )
          : $self->uploads->{$upload};
        }
    }

    if (@_ > 1) {
        while ( my($field, $upload) = splice(@_, 0, 2) ) {
            if ( exists $self->uploads->{$field} ) {
                for ( $self->uploads->{$field} ) {
                    $_ = [$_] unless ref($_) eq "ARRAY";
                    push(@{ $_ }, $upload);
                }
            } else {
                $self->uploads->{$field} = $upload;
            }
        }
    }
}

sub uploads {
    my ($self, $uploads) = @_;
    $self->context->engine->interface->prepare_body;
    $self->{uploads} = $uploads if $uploads;
    return $self->{uploads};
}

sub uri_with {
    my($self, $args) = @_;
    
    carp( 'No arguments passed to uri_with()' ) unless $args;

    for my $value (values %{ $args }) {
        next unless defined $value;
        for ( ref $value eq 'ARRAY' ? @{ $value } : $value ) {
            $_ = "$_";
            utf8::encode( $_ );
        }
    };
    
    my $uri = $self->uri->clone;
    
    $uri->query_form( {
        %{ $uri->query_form_hash },
        %{ $args },
    } );
    return $uri;
}

sub as_http_request {
    my $self = shift;
    HTTP::Request->new( $self->method, $self->uri, $self->headers, $self->raw_body );
}

sub absolute_url {
    my ($self, $location) = @_;

    unless ($location =~ m!^https?://!) {
        my $base = $self->req->base;
        my $url = sprintf '%s://%s', $base->scheme, $base->host;
        unless (($base->scheme eq 'http' && $base->port eq '80') ||
               ($base->scheme eq 'https' && $base->port eq '443')) {
            $url .= ':' . $base->port;
        }
        $url .= $base->path;
        $location = URI->new_abs($location, $url);
    }
    $location;
}


1;
