# -*- coding: utf-8 mode: perl -*- vim:sw=4:sts=4:et:ai:si:sta:fenc=utf-8
package Gitolite::Triggers::HostBasedAuth;

use Gitolite::Rc;
use Gitolite::Common;
use Gitolite::Conf::Load;
use HostBasedAuth::Common qw(log_info T get_host map_user hba_build_args hba_process_repo);
our $T;

use strict;
use warnings;

sub input {
    my @args = hba_build_args $ARGV[0] or return;

    # check verb
    my $git_commands = "git-upload-pack|git-receive-pack|git-upload-archive";
    my $create_command = "create";
    T "checking soc=\"$ENV{SSH_ORIGINAL_COMMAND}\" for verb in ($git_commands|$create_command)";
    if ( $ENV{SSH_ORIGINAL_COMMAND} =~ /($git_commands) '\/?(\S+)'$/ ) {
        my $command = $1;
        (my $repo = $2) =~ s/\.git$//;
        T "got repo=$repo with verb $command";

        return unless my $user = hba_process_repo @args, $repo;
        map_user $user;
    } elsif ( $ENV{SSH_ORIGINAL_COMMAND} =~ /($create_command) \/?(\S+)$/ ) {
        my $command = $1;
        (my $repo = $2) =~ s/\.git$//;
        T "got repo=$repo with verb $command";

        return unless my $user = hba_process_repo @args, $repo;
        map_user $user;
    }
}

1;
