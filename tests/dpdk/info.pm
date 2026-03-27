
# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package:
# Summary:
# Maintainer: cfamullaconrad@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Configure dpdk
    record_info('NUMA', script_output('lscpu | grep NUMA'));
    record_info('dpdk-hugepages', script_output('dpdk-hugepages.py -s'));

    record_info('lspci', script_output('lspci -nn -k'));
    record_info('dpdk-devbind', script_output('dpdk-devbind.py -s'));

    record_info('pkg', script_output(q(rpm -qa | grep -E 'dpdk|ovn|openvswitch|ovs' | xargs -IXXX bash -c 'echo -e "\n\n\n" ; rpm -qi XXX')));
    record_info('rpm -qa', script_output('rpm -qa'));

    record_info('cmdline', script_output('cat /proc/cmdline'));
    record_info('uname', script_output('uname -a'));
    record_info('os-release', script_output('cat /etc/os-release'));
}

sub test_flags {
    return {fatal => 1};
}

1;
