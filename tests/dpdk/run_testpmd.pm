# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: DPDK testpmd execution test
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'Dpdkbase';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call);
use Data::Dumper;
use mmapi;
use lockapi;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    Dpdkbase::download_data_dir();
    my $script = Dpdkbase::DPDK_DATA_DIR . '/dpdk/run_testpmd.sh';
    assert_script_run("chmod +x $script");

    my $threshold = "--threshold-tx 640000 --threshold-rx 640000";
    my $cmd_tx = sprintf("%s -a %s -a %s --mode tx_start $threshold",
        $script, $self->pci3, $self->pci4);
    my $cmd_fwd = sprintf("%s -a %s -a %s --mode fwd $threshold",
        $script, $self->pci3, $self->pci4);

    barrier_wait({name => 'wait_1', check_dead_job => 1});
    if (get_var('DPDK_HOST') eq 1) {
        $self->run_test_shell_script($script, $cmd_tx);
    } else {
        $self->run_test_shell_script($script, $cmd_fwd);
    }

    barrier_wait({name => 'wait_2', check_dead_job => 1});
    if (get_var('DPDK_HOST') eq 3) {
        $self->run_test_shell_script($script, $cmd_tx);
    } else {
        $self->run_test_shell_script($script, $cmd_fwd);
    }

    barrier_wait({name => 'wait_3', check_dead_job => 1});
    if (get_var('DPDK_HOST') eq 3) {
        $self->run_test_shell_script($script, $cmd_tx);
    } else {
        $self->run_test_shell_script($script, $cmd_fwd);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
