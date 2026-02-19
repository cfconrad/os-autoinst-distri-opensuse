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
use utils qw(zypper_call systemctl file_content_replace zypper_ar ensure_ca_certificates_suse_installed);
use bootloader_setup;
use repo_tools 'generate_version';
use registration;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Enable kernel iommu via cmdline
    add_grub_cmdline_settings('iommu=pt intel_iommu=on', update_grub => 1);
    serial_terminal::reboot();
    record_info('cmdline', script_output('cat /proc/cmdline'));

    # Install needed packages
    my @pk = qw(pciutils openvswitch dpdk-tools);
    for my $p (@pk) {
        zypper_call('in ' . $p);
    }

    # Configure dpdk
    record_info('NUMA', script_output('lscpu | grep NUMA'));
    assert_script_run('echo 256 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages');
    record_info('dpdk-hugepages', script_output('dpdk-hugepages.py -s'));

    record_info('lspci', script_output('lspci -nn -k'));
    my $pci_id = script_output(q(lspci | grep Ethernet | grep Intel | awk '{print $1}' | sed -n 1p));
    assert_script_run('modprobe vfio-pci');
    assert_script_run('dpdk-devbind.py --bind  vfio-pci ' . $pci_id);
    record_info('dpdk-devbind', script_output('dpdk-devbind.py -s'));


    # Setup openvswitch with DPDK device
    assert_script_run('chown -R openvswitch:openvswitch /dev/hugepages');
    assert_script_run('chown -R openvswitch:openvswitch /dev/vfio/');
    assert_script_run('systemctl start openvswitch');
    assert_script_run('ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true');
    assert_script_run('ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="512,0"');

    # Optional: Pin PMDs to specific cores (e.g., cores 1,2)
    assert_script_run('ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0x6');
    assert_script_run('systemctl restart openvswitch');

    validate_script_output('ovs-vsctl get Open_vSwitch . dpdk_initialized', qr/^true$/);
    assert_script_run('test $(ovs-vsctl get Open_vSwitch . dpdk_initialized) == true');

    # Create bridge and add physical DPDK port
    assert_script_run('ovs-vsctl add-br br-dpdk -- set bridge br-dpdk datapath_type=netdev');
    assert_script_run("ovs-vsctl add-port br-dpdk dpdk0 -- set Interface dpdk0 type=dpdk options:dpdk-devargs=$pci_id");

    assert_script_run('ovs-vsctl add-port br-dpdk mgmt0 tag=1092 -- set Interface mgmt0 type=internal');

    validate_script_output('ovs-vsctl get Interface dpdk0 type', qr/^dpdk$/);

}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
