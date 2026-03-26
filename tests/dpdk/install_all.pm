# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pciutils openvswitch dpdk-tools
# Summary: Install DPDK and Open vSwitch packages
# Maintainer: cfamullaconrad@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call);

sub run {
    my @packages = qw(
      dpdk
      dpdk
      dpdk-debuginfo
      dpdk-debugsource
      dpdk-devel
      dpdk-devel-static
      dpdk-doc
      dpdk-examples
      dpdk-examples-debuginfo
      dpdk-tools
      dpdk-tools
      libdpdk-%LIBDPDK_VERSION%
      libdpdk-%LIBDPDK_VERSION%-debuginfo
      libopenvswitch-%LIBOVS_VERSION%
      libopenvswitch-%LIBOVS_VERSION%-debuginfo
      libovn-%LIBOVN_VERSION%
      libovn-%LIBOVN_VERSION%-debuginfo
      openvswitch
      openvswitch-debuginfo
      openvswitch-debugsource
      openvswitch-devel
      openvswitch-doc
      openvswitch-ipsec
      openvswitch-pki
      openvswitch-test
      openvswitch-test-debuginfo
      openvswitch-vtep
      openvswitch-vtep-debuginfo
      ovn
      ovn-br-controller
      ovn-br-controller-debuginfo
      ovn-central
      ovn-central-debuginfo
      ovn-debuginfo
      ovn-devel
      ovn-doc
      ovn-docker
      ovn-host
      ovn-host-debuginfo
      ovn-vtep
      ovn-vtep-debuginfo
      python3-openvswitch
      python3-openvswitch-debuginfo);

    my @missed;
    for my $pkg (@packages) {
        $pkg =~ s/%([^%]+)%/get_var($1,'')/ge;

        if (script_run("zypper -q search -x $pkg") == 0) {
            zypper_call("zypper in $pkg");
        } else {
            push(@missed, $pkg);
        }
    }
    record_info('missed', "@missed");
}


1;
