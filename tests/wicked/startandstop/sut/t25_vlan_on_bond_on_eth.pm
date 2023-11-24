# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: VLAN on Bond of physical interfaces
#
#          eth1,eth2   -m->    bond0   <-l-    bond0.11
#         
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my ($ifc1, $ifc2) = $ctx->iface(2);

    $self->get_from_data('wicked/scripts/ifupdown', '/tmp/');
    assert_script_run('cd /tmp/ifupdown/test-2.3');
    $self->run_test_shell_script("ifupdown-2.3", "time eth0=$ifc1 eth1=$ifc2 bash ./test.sh");
    $self->skip_check_logs_on_post_run();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
