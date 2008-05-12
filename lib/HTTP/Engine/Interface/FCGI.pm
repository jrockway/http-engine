package HTTP::Engine::Interface::FCGI;
use Moose;
with 'HTTP::Engine::Role::Interface';
use constant should_write_response_line => 0;
use FCGI;
use UNIVERSAL::require;

has leave_umask => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has keep_stderr => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has nointr => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has detach => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has manager => (
    is      => 'ro',
    isa     => 'Str',
    default => "FCGI::ProcManager",
);

has nproc => (
    is      => 'ro',
    isa     => 'Int',
    default => 1,
);

has pidfile => (
    is      => 'ro',
    isa     => 'Str',
);

has listen => (
    is  => 'ro',
    isa => 'Int',
);

sub run {
    my ( $self, ) = @_;

    my $sock = 0;
    if ($self->listen) {
        my $old_umask = umask;
        unless ( $self->leave_umask ) {
            umask(0);
        }
        $sock = FCGI::OpenSocket( $self->listen, 100 )
          or die "failed to open FastCGI socket; $!";
        unless ( $self->leave_umask ) {
            umask($old_umask);
        }
    }
    elsif ( $^O ne 'MSWin32' ) {
        -S STDIN
          or die "STDIN is not a socket; specify a listen location";
    }

    my %env;
    my $error = \*STDERR;    # send STDERR to the web server
    $error = \*STDOUT                # send STDERR to stdout (a logfile)
      if $self->keep_stderr;         # (if asked to)

    my $request =
      FCGI::Request( \*STDIN, \*STDOUT, $error, \%env, $sock,
        ( $self->nointr ? 0 : &FCGI::FAIL_ACCEPT_ON_INTR ),
      );

    my $proc_manager;

    if ($self->listen) {
        $self->daemon_fork() if $self->detach;

        if ( $self->manager ) {
            $self->manager->use or die $@;
            $proc_manager = $self->manager->new(
                {
                    n_processes => $self->nproc,
                    pid_fname   => $self->pidfile,
                }
            );

            # detach *before* the ProcManager inits
            $self->daemon_detach() if $self->detach;

            $proc_manager->pm_manage();
        }
        elsif ( $self->detach ) {
            $self->daemon_detach();
        }
    }

    while ( $request->Accept >= 0 ) {
        $proc_manager && $proc_manager->pm_pre_dispatch();

        # If we're running under Lighttpd, swap PATH_INFO and SCRIPT_NAME
        # http://lists.rawmode.org/pipermail/catalyst/2006-June/008361.html
        # Thanks to Mark Blythe for this fix
        if ( $env{SERVER_SOFTWARE} && $env{SERVER_SOFTWARE} =~ /lighttpd/ ) {
            $env{PATH_INFO} ||= delete $env{SCRIPT_NAME};
        }

        local %ENV = %env;
        $self->handle_request();

        $proc_manager && $proc_manager->pm_post_dispatch();
    }
}

sub daemon_fork {
    require POSIX;
    fork && exit;
}

sub daemon_detach {
    my $self = shift;
    print "FastCGI daemon started (pid $$)\n";
    open STDIN,  "+</dev/null" or die $!; ## no critic
    open STDOUT, ">&STDIN"     or die $!;
    open STDERR, ">&STDIN"     or die $!;
    POSIX::setsid();
}

1;
__END__

=head1 AUTHORS

Tokuhiro Matsuno

=head1 THANKS TO

may codes copied from L<Catalyst::Engine::FastCGI>. thanks authors of C::E::FastCGI!

