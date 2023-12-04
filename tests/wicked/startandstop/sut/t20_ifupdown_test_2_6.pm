# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Generic script/ifupdown/test-* runner
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx, $script_test) = @_;
    my $ifc1 = $ctx->iface;
    my $ifc2 = $ctx->iface2;

    if ( $self->{name} !~ m/t\d+_ifupdown_(test_\d+_\d+)/) {
        die ("Testname doesn't have expected format!");
    }
    my $test = $1;
    $test =~ s/_/-/;
    $test =~ s/_/./;

    $self->get_from_data('wicked/scripts/ifupdown', '/tmp/');
    assert_script_run('cd /tmp/ifupdown/' . $test);
    sleep;
    $self->run_test_shell_script($test, "time eth0=$ifc1 eth1=$ifc2 bash ./test.sh");
    $self->skip_check_logs_on_post_run();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
