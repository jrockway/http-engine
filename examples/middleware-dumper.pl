use strict;
use warnings;
use lib 'lib';
use Data::Dumper;
use HTTP::Engine middlewares => [qw/+examples::MiddleWare/];
use HTTP::Engine::Interface::ServerSimple;
use HTTP::Response;
use HTTP::Engine::Request;
use HTTP::MobileAttribute;
use String::TT qw/strip tt/;

my $engine = HTTP::Engine->new(
    interface => {
        module  => 'ServerSimple',
        args => {
            port    => 14000,
        },
        request_handler => sub {
            my $c = shift;
            local $Data::Dumper::Sortkeys = 1;
            my $req_dump = Dumper( $c->req );
            my $ma = $c->req->mobile_attribute;
            my $raw      = $c->req->raw_body;
            my $body     = strip tt q{ 
                <form method="post">
                    <input type="text" name="foo" />
                    <input type="submit" />
                </form>

                <form method="post" enctype="multipart/form-data">
                    <input type="file" name="upload_file" />
                    <input type="submit" />
                </form>
                REGEXP TEXT

                <pre>[% raw      | html %]</pre>
                <pre>[% req_dump | html %]</pre>
                <pre>[% ma       | html %]</pre>
            };

            $c->res->body($body);
        },
    },
    plugins => [qw/DebugScreen/],
);
$engine->load_plugins(qw/DebugScreen ModuleReload MobileAttribute/);
$engine->run;

