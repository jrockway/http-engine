#!/bin/zsh

# generate to t/00_allload.t
echo "
use strict;
use warnings;
use Test::More;

my @modules = qw(
" > t/00_allload.t

find lib -name "*.pm" | sed "s/lib\//    /;s/\.pm//;s/\//::/g" | grep -v 'HTTP::Engine::Interface' >> t/00_allload.t

echo "
);

plan tests => scalar(@modules);

use_ok \$_ for @modules;
" >> t/00_allload.t

rm -rf cover_db
perl Makefile.PL
HARNESS_PERL_SWITCHES=-MDevel::Cover=+ignore,inc,-coverage,statement,branch,condition,path,subroutine make test
cover
rm t/00_allload.t
open cover_db/coverage.html
