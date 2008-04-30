package HTTP::Engine;
use Moose;
BEGIN { eval "package HTTPEx; sub dummy {} 1;" }
use base 'HTTPEx';
our $VERSION = '0.0.2';

use HTTP::Engine::Context;
use HTTP::Engine::Request;
use HTTP::Engine::Request::Upload;
use HTTP::Engine::Response;

has handler => (
    is       => 'rw',
    isa      => 'CodeRef',
    required => 1,
);

has interface => (
    is  => 'rw',
    does => 'HTTP::Engine::Role::Interface',
    required => 1,
);

# TODO: HTTP::Engine::Role::ErrorHandler
sub errors       { shift->{errors} }
sub push_errors  { push @{ shift->{errors} }, @_ }
sub clear_errors { shift->{errors} = [] }

sub handle_request {
    my $self = shift;

    $self->clear_errors();

    $self->interface->initialize();

    my %env = @_;
       %env = %ENV unless %env;

    my $context = HTTP::Engine::Context->new(
        engine => $self,
        req    => HTTP::Engine::Request->new(),
        res    => HTTP::Engine::Response->new(),
        env    => \%env,
    );

    $self->interface->prepare( $context );

    my $ret = eval {
        $self->handler->($context);
    };
#   {
#       local $@;
#       $self->run_hook( after_handle_request => $context );
#   }
    if (my $e = $@) {
        $self->push_errors($e);
#       $self->run_hook('handle_error', $context);
    }
    $self->interface->finalize( $context );

    $ret;
}

sub run {
    my $self = shift;
    $self->interface->run($self);
}

1;
__END__

=encoding utf8

=head1 NAME

HTTP::Engine - Web Server Gateway Interface and HTTP Server Engine Drivers (Yet Another Catalyst::Engine)

=head1 SYNOPSIS

  use HTTP::Engine;
  HTTP::Engine->new(
    config         => 'config.yaml',
    handle_request => sub {
      my $c = shift;
      $c->res->body( Dumper($e->req) );
    }
  )->run;

=head1 CONCEPT RELEASE

Version 0.0.x is a concept release, the internal interface is still fluid. 
It is mostly based on the code of Catalyst::Engine.

=head1 DESCRIPTION

HTTP::Engine is a bare-bones, extensible HTTP engine. It is not a 
socket binding server. The purpose of this module is to be an 
adaptor between various HTTP-based logic layers and the actual 
implementation of an HTTP server, such as, mod_perl and FastCGI

=head1 PLUGINS

For all non-core plugins (consult #codrepos first), use the HTTPEx::
namespace. For example, if you have a plugin module named "HTTPEx::Plugin::Foo",
you could load it as

  use HTTP::Engine;
  HTTP::Engine->load_plugins(qw( +HTTPEx::Plugin::Foo ));

=head1 AUTHOR

Kazuhiro Osawa E<lt>ko@yappo.ne.jpE<gt>

=head1 COMMITTERS

lestrrat

tokuhirom

=head1 THANKS TO

marcus

=head1 SEE ALSO

=head1 REPOSITORY

  svn co http://svn.coderepos.org/share/lang/perl/HTTP-Engine/trunk HTTP-Engine

HTTP::Engine's Subversion repository is hosted at L<http://coderepos.org/share/>.
patches and collaborators are welcome.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
