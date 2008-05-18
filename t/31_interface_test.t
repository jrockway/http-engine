use strict;
use warnings;
use HTTP::Engine;
use HTTP::Request;
use Test::Base;

plan tests => 1*blocks;

filters {
    response => [qw/chop/],
};

run {
    my $block = shift;

    my $response = HTTP::Engine->new(
        interface => {
            module => 'Test',
            request_handler => sub {
                my $c = shift;
                $c->res->header( 'X-Req-Base' => $c->req->base );
                $c->res->body('OK!');
            },
        },
    )->run(HTTP::Request->new( GET => 'http://localhost/'));

    $response->headers->remove_header('Date');
    my $data = $response->headers->as_string."\n".$response->content;
    is $data, $block->response;
};

sub crlf {
    my $in = shift;
    $in =~ s/\n/\r\n/g;
    $in;
}

__END__

===
--- response
Content-Length: 3
Content-Type: text/html
Status: 200
X-Req-Base: http://localhost/

OK!