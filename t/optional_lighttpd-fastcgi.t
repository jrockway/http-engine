use strict;
use warnings;

# this file is copied from Catalyst. thanks!

use File::Path;
use FindBin;
use IO::Socket;
use Test::More;

plan skip_all => 'set TEST_LIGHTTPD to enable this test' 
    unless $ENV{TEST_LIGHTTPD};
    
eval "use FCGI";
plan skip_all => 'FCGI required' if $@;

eval "use Test::Harness";
plan skip_all => 'Test::Harness required' if $@;

my $lighttpd_bin = $ENV{LIGHTTPD_BIN} || `which lighttpd`;
chomp $lighttpd_bin;

plan skip_all => 'Please set LIGHTTPD_BIN to the path to lighttpd'
    unless $lighttpd_bin && -x $lighttpd_bin;

plan tests => 1;

# clean up
rmtree "$FindBin::Bin/../t/tmp" if -d "$FindBin::Bin/../t/tmp";

# create a TestApp and copy the test libs into it
mkdir "$FindBin::Bin/../t/tmp";
chdir "$FindBin::Bin/../t/tmp";
chdir "$FindBin::Bin/..";

# remove TestApp's tests
rmtree 't/tmp/TestApp/t';

# Create a temporary lighttpd config
my $docroot = "$FindBin::Bin/../t/tmp";
my $port    = 8529;

# Clean up docroot path
$docroot =~ s{/t/..}{};

my $conf = <<"END";
# basic lighttpd config file for testing fcgi+HTTP::Engine
server.modules = (
    "mod_access",
    "mod_fastcgi",
    "mod_accesslog"
)

server.document-root = "$docroot"

server.errorlog    = "$docroot/error.log"
accesslog.filename = "$docroot/access.log"

server.bind = "127.0.0.1"
server.port = $port

# HTTP::Engine app specific fcgi setup
fastcgi.server = (
    "" => (
        "FastCgiTest" => (
            "socket"          => "$docroot/test.socket",
            "check-local"     => "disable",
            "bin-path"        => "$docroot/test_fastcgi.pl",
            "min-procs"       => 1,
            "max-procs"       => 1,
            "idle-timeout"    => 20,
            "bin-environment" => (
                "PERL5LIB" => "$docroot/../../lib"
            )
        )
    )
)
END

open(my $lightconf, '>', "$docroot/lighttpd.conf") 
  or die "Can't open $docroot/lighttpd.conf: $!";
print {$lightconf} $conf or die "Write error: $!";
close $lightconf;

my $pid = open my $lighttpd, "$lighttpd_bin -D -f $docroot/lighttpd.conf 2>&1 |" 
    or die "Unable to spawn lighttpd: $!";
    
# wait for it to start
while ( check_port( 'localhost', $port ) != 1 ) {
    diag "Waiting for server to start...";
    sleep 1;
}

# DO TESTS.
warn "XXX ここでテストする XXXX";

# shut it down
kill 'INT', $pid;
close $lighttpd;

# clean up
rmtree "$FindBin::Bin/../t/tmp" if -d "$FindBin::Bin/../t/tmp";

sub check_port {
    my ( $host, $port ) = @_;

    my $remote = IO::Socket::INET->new(
        Proto    => "tcp",
        PeerAddr => $host,
        PeerPort => $port
    );
    if ($remote) {
        close $remote;
        return 1;
    }
    else {
        return 0;
    }
}
