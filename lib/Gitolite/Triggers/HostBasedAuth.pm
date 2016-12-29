# -*- coding: utf-8 mode: perl -*- vim:sw=4:sts=4:et:ai:si:sta:fenc=utf-8
package Gitolite::Triggers::HostBasedAuth;

use Gitolite::Rc;
use Gitolite::Common;
use Gitolite::Conf::Load;

use strict;
use warnings;

sub input {
    my $anon_user = $rc{HOST_BASED_AUTH}{ANON_USER} || $rc{HTTP_ANON_USER} || 'anonhttp';
    my $host_user = $rc{HOST_BASED_AUTH}{HOST_USER} || 'anonhost';

    # only map anon_user
    my $user = $ARGV[0];
    gl_log("input", "hba", "checking //$user// == $anon_user");
    return if $user ne $anon_user;

    my $git_commands = "git-upload-pack|git-receive-pack|git-upload-archive";
    gl_log("input", "hba", "checking //$ENV{SSH_ORIGINAL_COMMAND}// for verb in ($git_commands)");
    if ( $ENV{SSH_ORIGINAL_COMMAND} =~ /(?:$git_commands) '\/?(\S+)'$/ ) {
        my $repo = $1;
        $repo =~ s/\.git$//;
            
        my $ip = $ENV{SSH_CONNECTION} || '(no-IP)';
        $ip =~ s/ .*//;

        my $allows = git_config($repo, "^gitolite-options\\.allow-from([.-].*)?");
        my @allows = map {split} values %$allows;

        gl_log("input", "hba", "checking repo $repo for ip $ip in (".join(", ", @allows).")");
        for my $allow (@allows) {
            if ($allow eq $ip) {
                gl_log("input", "hba", "found $ip match with $allow", "mapping to $host_user");
                $ARGV[0] = $host_user;
                $ENV{REMOTE_USER} = $host_user;
                last;
            }
        }
    }
}

1;
