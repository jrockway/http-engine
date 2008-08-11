use strict;
use warnings;
use Test::More;
use t::Utils;
plan skip_all => 'you do not set $ENV{RUN_LIVETESTS}.will skip this test' unless $ENV{RUN_LIVETESTS};
plan tests => 2;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST $DYNAMIC_FILE_UPLOAD);
use HTTP::Engine;
use t::Utils;

my $port = empty_port;

&main; exit();

sub main {
    if (my $pid = fork()) {
        # parent.
        sleep 1; # wait startup child process

        do_request();

        kill TERM => $pid;
        waitpid($pid, 0);
    } elsif ($pid == 0) {
        # child
        run_server();
    } else {
        die "cannot fork";
    }
}

sub do_request {
    my $ua = LWP::UserAgent->new(timeout => 10);
    my $req = POST("http://localhost:$port/", Content_Type => 'multipart/form-data;', Content => ['test' => ["README"]]);
    my $res = $ua->request($req);
    is $res->code, 200;
    like $res->content, qr{Kazuhiro Osawa};
}

sub run_server {
    HTTP::Engine->new(
        interface => {
            module => 'ServerSimple',
            args => {
                port => $port,
            },
            request_handler => sub {
                my $req = shift;
                HTTP::Engine::Response->new(body => $req->upload("test")->slurp(), status => 200);
            },
        },
    )->run;
}

