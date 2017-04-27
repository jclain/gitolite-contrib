# -*- coding: utf-8 mode: perl -*- vim:sw=4:sts=4:et:ai:si:sta:fenc=utf-8
package HostBasedAuth::Common;

@EXPORT_OK = qw(log_info log_die T get_host map_user hba_build_args hba_process_repo);
@EXPORT = qw(hba_build_args hba_process_repo);
use Exporter 'import';
use Socket;
use NetAddr::IP::Lite;
use Gitolite::Rc;
use Gitolite::Common;
use Gitolite::Conf::Load;

use strict;
use warnings;

sub log_info {
   gl_log("input", "host-based-auth", @_);
}
sub log_die { # die with a single message, but log more info
    log_info(@_);
    _die($_[0]);
}
my $T = 1; # 1 to enable trace, 0 to disable
sub T { # trace if $T is true
    trace(1, @_) if $T;
}

sub get_host {
    my $ip = shift;
    my $addr = inet_aton($ip);
    my $host = gethostbyaddr($addr, AF_INET);
    return $host
}

my $re_ip = qr/^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$/;
my $re_host = qr/^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$/;
sub __is_host {
    my $host = shift;
    # not an IP address first
    return 0 if $host =~ $re_ip;
    return $host =~ $re_host;
}

sub map_user {
    my $user = shift;
    $ENV{ORIG_REMOTE_USER} = $ENV{REMOTE_USER};
    $ENV{REMOTE_USER} = $user;
    $ARGV[0] = $user;
}

sub hba_build_args {
    log_info() if $T;

    # only map anon_user
    my $user = shift;
    my $anon_user = $rc{HTTP_ANON_USER} || 'anonhttp';
    T "checking if user=$user is $anon_user";
    return if $user ne $anon_user;

    # check ip
    (my $clientip = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{SSH_CONNECTION} || '') =~ s/ .*//;
    my $clientipdesc = $clientip || "(None)";
    T "got clientip=$clientipdesc";
    return unless $clientip;
    my $clienthost = get_host($clientip);
    (my $clientname = $clienthost) =~ s/\..*$//;
    (my $clientdomain = $clienthost) =~ s/^[^.]+//;
    T "clientip=$clientip resolves to clienthost=$clienthost";

    return ($anon_user, $user, $clientip, $clienthost, $clientname, $clientdomain);
}

sub hba_process_repo {
    my ($anon_user, $user, $clientip, $clienthost, $clientname, $clientdomain, $repo) = @_;

    my $match_repo = option($repo, "match-repo");
    my @matches;
    if ($match_repo) {
        T "got option \"match-repo = $match_repo\", trying to match...";
        @matches = map { defined() ? $_: '' } $repo =~ $match_repo;
        T "got \@matches=(@matches)";
        return unless @matches;
    }

    my $map_anonhttps = git_config($repo, "^gitolite-options\\.(map-anonhttp|anonhttp-is)([.-].*)?");
    while (my ($option, $map_anonhttp) = each(%$map_anonhttps)) {
        T "parsing option \"$option = $map_anonhttp\"";
        my ($to_user, $from_hosts) = $map_anonhttp =~ /^(\S+)\s*from\s*(.+)$/
            or log_die("malformed option", "syntax is \"user from hosts...\"");
        $to_user =~ $USERNAME_PATT
            or log_die("malformed option", "invalid user '$to_user'");
        T "got to_user=$to_user";
        my @from_hosts = split(' ', $from_hosts);
        T "got \@from_hosts=(@from_hosts)";

        for my $from_host (@from_hosts) {
            T "checking from_host=$from_host";
            if ($match_repo) {
                my $thost = $from_host;
                for my $i (0 .. $#matches) {
                    my $from = '\$'.($i + 1);
                    my $to = defined($matches[$i])? $matches[$i]: '';
                    $thost =~ s/$from/$to/e;
                }
                T "from_host=$from_host translates to from_host=$thost";
                $from_host = $thost;
            }

            if ($from_host =~ /^(?:~.+|\/.+\/)$/) {
                # regex match
                if ($from_host =~ /^~(.+)/) {
                    # quote '.' and add anchors
                    $from_host = $1;
                    $from_host =~ s/\./\\./g;
                    $from_host = '^'.$from_host.'$';
                } elsif ($from_host =~ /\/(.+)\//) {
                    # use the regex as-is
                    $from_host = $1;
                }

                if ($from_host =~ /\\\.|\[[^]]*\.[^]]*\]/) {
                    # host with domain
                    T "trying regex match against clienthost=$clienthost";
                    if ($clienthost =~ /$from_host/i) {
                        T "...matched";
                        log_info("clienthost=$clienthost matches with regex from_host=$from_host", "mapping $anon_user to $to_user");
                        return $to_user;
                    }

                } else {
                    # hostname without domain
                    T "trying regex match against clientname=$clientname";
                    if ($clientname =~ /$from_host/i) {
                        T "...matched";
                        log_info("clientname=$clientname matches with regex from_host=$from_host", "mapping $anon_user to $to_user");
                        return $to_user;
                    }
                }

                T "...not matched";

            } elsif (__is_host($from_host)) {
                $from_host =~ s/^\*\././;          # *.domain   === .domain
                $from_host =~ s/^([^.]+)\.\*$/$1/; # hostname.* === hostname
                if ($from_host =~ /^\./) {
                    # .domain match
                    T "trying .domain match";
                    if (lc $from_host eq lc $clientdomain) {
                        T "...matched";
                        log_info("clientdomain=$clientdomain matches with from_host=$from_host", "mapping $anon_user to $to_user");
                        return $to_user;
                    }

                } elsif ($from_host =~ /\./) {
                    # host.domain match
                    T "trying host.domain match";
                    if (lc $from_host eq lc $clienthost) {
                        T "...matched";
                        log_info("clienthost=$clienthost matches with from_host=$from_host", "mapping $anon_user to $to_user");
                        return $to_user;
                    }

                } else {
                    # host match
                    T "trying host match";
                    if (lc $from_host eq lc $clientname) {
                        T "...matched";
                        log_info("clientname=$clientname matches with from_host=$from_host", "mapping $anon_user to $to_user");
                        return $to_user;
                    }
                }

                T "...not matched";

            } elsif (my $from_hostip = new NetAddr::IP::Lite($from_host)) {
                # ip match
                T "$from_host translates to $from_hostip";
                my $maskip = new NetAddr::IP::Lite($clientip, $from_hostip->mask());

                T "trying ip match";
                if ($from_hostip->network() eq $maskip->network()) {
                        T "...matched";
                    log_info("matched clientip=$clientip with from_host=$from_host", "mapping $anon_user to $to_user");
                    return $to_user;
                }

                T "...not matched";
            }
        }
    }
    return undef;
}

1;
