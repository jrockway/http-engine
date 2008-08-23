use strict;
use warnings;
use t::Utils;
use Test::TCP;
use LWP::UserAgent;
use Test::More;

plan tests => 1;

test_tcp(
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new(keep_alive => 1);
        my $res = $ua->request(HTTP::Request->new('RESTART', "http://localhost:$port/"));
        is $res->code, 500;
    },
    server => sub {
        my $port = shift;
        HTTP::Engine->new(
            interface => {
                module => 'Standalone',
                args   => {
                    port      => $port,
                },
                request_handler => sub { },
            },
        )->run;
    },
);
