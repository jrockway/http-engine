use strict;
use warnings;
use HTTP::Engine;
use HTTP::Headers;
use HTTP::Request;
use Test::Base;

plan tests => 1*blocks;

filters {
    response => [qw/chop/],
};

run {
    my $block = shift;
    my $test;
    my $body;

    if ($block->request && exists $block->request->{method} && $block->request->{method} eq 'POST') {
        delete $block->request->{method};
        $body = delete $block->request->{body};
        my $content = delete $block->request->{content};
        $content =~ s/\r\n/\n/g;
        $content =~ s/\n/\r\n/g;
        $test = HTTP::Request->new( POST => 'http://localhost/', HTTP::Headers->new( %{ $block->request } ), $content );
    } else {
        $test = HTTP::Request->new( GET => 'http://localhost/');
    }

    my $response = HTTP::Engine->new(
        interface => {
            module => 'Test',
            request_handler => sub {
                my $c = shift;
                $c->res->header( 'X-Req-Base' => $c->req->base );
                $c->res->body('OK!');
                return unless $body;
                return unless $c->req->uploads->{test_upload_file};
                unless ($body eq $c->req->uploads->{test_upload_file}->slurp) {
                    $c->res->body('NG');
                }
            },
        },
    )->run($test);

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
--- request yaml
method: POST
content: |
  ------BOUNDARY
  Content-Disposition: form-data; name="test_upload_file"; filename="yappo.txt"
  Content-Type: text/plain
  
  SHOGUN
  ------BOUNDARY--
Content-Type: multipart/form-data; boundary=----BOUNDARY
Content-Length: 149
body: SHOGUN
--- response
Content-Length: 3
Content-Type: text/html
Status: 200
X-Req-Base: http://localhost/

OK!
===
--- resquest
--- response
Content-Length: 3
Content-Type: text/html
Status: 200
X-Req-Base: http://localhost/

OK!
