use strict;
use warnings;
use Test::More tests => 4;
use t::Utils;
use HTTP::Engine;
use HTTP::Request;
use HTTP::Engine::RequestBuilder;


do {
    run_engine {
        my $req = shift;
        is $req->raw_body => 'test';
        HTTP::Engine::Response->new( body => '' );
    } HTTP::Request->new( GET => 'http://localhost/')
        => ( req => HTTP::Engine::Request->new( method => 'GET', raw_body => 'test', request_builder => HTTP::Engine::RequestBuilder->new ) );
};

do {
    run_engine {
        my $req = shift;
        isa_ok $req, 'HTTP::Engine::Request';
        HTTP::Engine::Response->new( body => '' );
    } HTTP::Request->new( GET => 'http://localhost/');
};

do {
    no strict 'refs';
    no warnings 'redefine';
    local *HTTP::Engine::Request::new = sub { return };
    local $@;
    eval {
        run_engine {
            my $req = shift;
            ok !!!$req;
            HTTP::Engine::Response->new( body => '' );
        } HTTP::Request->new( GET => 'http://localhost/') => ( request_args => undef );
    };
    like $@, qr/Can't call method/;
};
