# -*- coding: utf-8 mode: perl -*- vim:sw=4:sts=4:et:ai:si:sta:fenc=utf-8
package Gitolite::Triggers::HostBasedAuth;

use Socket;
use NetAddr::IP::Lite;
use Gitolite::Rc;
use Gitolite::Common;
use Gitolite::Conf::Load;

use strict;
use warnings;

sub __get_host {
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

sub __replace_user {
    my $user = shift;
    $ENV{ORIG_REMOTE_USER} = $ENV{REMOTE_USER};
    $ENV{REMOTE_USER} = $user;
    $ARGV[0] = $user;
}

sub input {
    my $anon_user = $rc{HOST_BASED_AUTH}{ANON_USER} || $rc{HTTP_ANON_USER} || 'anonhttp';
    my $host_user = $rc{HOST_BASED_AUTH}{HOST_USER} || 'anyhost';

    gl_log("input", "host-based-auth");

    # only map anon_user
    my $user = $ARGV[0];
    trace(2, "checking if user=$user is $anon_user");
    return if $user ne $anon_user;

    # check ip
    (my $clientip = $ENV{SSH_CONNECTION} || '') =~ s/ .*//;
    my $clientipdesc = $clientip || "(None)";
    trace(2, "got clientip=$clientipdesc");
    return unless $clientip;
    my $clienthost = __get_host($clientip);
    (my $clientname = $clienthost) =~ s/\..*$//;
    (my $clientdomain = $clienthost) =~ s/^[^.]+//;
    trace(2, "clientip=$clientip resolves to clienthost=$clienthost");

    # check verb
    my $git_commands = "git-upload-pack|git-receive-pack|git-upload-archive";
    trace(2, "checking soc=\"$ENV{SSH_ORIGINAL_COMMAND}\" for verb in ($git_commands)");
    if ( $ENV{SSH_ORIGINAL_COMMAND} =~ /(?:$git_commands) '\/?(\S+)'$/ ) {
        (my $repo = $1) =~ s/\.git$//;
        trace(2, "got repo=$repo");

        my $match_repo = option($repo, "match-repo");
        my @matches;
        if ($match_repo) {
            trace(2, "got match-repo=$match_repo");
            @matches = $repo =~ $match_repo;
            trace(2, "got \@matches=(@matches)");
            return unless @matches;
        }

        my $allow_hosts = git_config($repo, "^gitolite-options\\.allow-host([.-].*)?");
        my @allow_hosts = map {split} values %$allow_hosts;
        trace(2, "got \@allow-hosts=(@allow_hosts)");

        for my $allow (@allow_hosts) {
            trace(2, "checking allow-host=$allow");
            if ($match_repo) {
                my $tallow = $allow;
                for my $i (0 .. $#matches) {
                    my $from = '\$'.($i + 1);
                    my $to = $matches[$i];
                    $tallow =~ s/$from/$to/e;
                }
                trace(2, "allow-host=$allow translates to allow-host=$tallow");
                $allow = $tallow;
            }
            if (__is_host($allow)) {
                if ($allow =~ /^\./) {
                    # .domain match
                    trace(2, "trying .domain match");
                    if (lc $allow eq lc $clientdomain) {
                        gl_log("input", "host-based-auth", "clientdomain=$clientdomain matches with allow-host=$allow", "mapping $anon_user to $host_user");
                        __replace_user($host_user);
                        last;
                    } else {
                        trace(2, "...not matched");
                    }
                } elsif ($allow =~ /\./) {
                    # host.domain match
                    trace(2, "trying host.domain match");
                    if (lc $allow eq lc $clienthost) {
                        gl_log("input", "host-based-auth", "clienthost=$clienthost matches with allow-host=$allow", "mapping $anon_user to $host_user");
                        __replace_user($host_user);
                        last;
                    } else {
                        trace(2, "...not matched");
                    }
                } else {
                    # host match
                    trace(2, "trying host match");
                    if (lc $allow eq lc $clientname) {
                        gl_log("input", "host-based-auth", "clientname=$clientname matches with allow-host=$allow", "mapping $anon_user to $host_user");
                        __replace_user($host_user);
                        last;
                    } else {
                        trace(2, "...not matched");
                    }
                }
            } elsif (my $allowip = new NetAddr::IP::Lite($allow)) {
                # ip match
                trace(2, "$allow translates to $allowip");
                my $maskip = new NetAddr::IP::Lite($clientip, $allowip->mask());
                trace(2, "trying ip match");
                if ($allowip->network() eq $maskip->network()) {
                    gl_log("input", "host-based-auth", "matched clientip=$clientip with allow-host=$allow", "mapping $anon_user to $host_user");
                    __replace_user($host_user);
                    last;
                } else {
                    trace(2, "...not matched");
                }
            }
        }
    }
}

1;
