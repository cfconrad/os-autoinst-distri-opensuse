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
use utils qw(zypper_call systemctl file_content_replace zypper_ar ensure_ca_certificates_suse_installed);
use repo_tools 'generate_version';
use registration;


sub install_custom_package()
{
    my $custom_pkg = get_var('INSTALL_RPM');

    return unless $custom_pkg;

    if ($custom_pkg =~ /suse\.de/ && script_run('rpm -qi ca-certificates-suse') == 1) {
        my $repo_url = "https://download.opensuse.org/repositories/SUSE:/CA/";
        zypper_ar($repo_url . generate_version('_') . '/', name => 'suse_ca', no_gpg_check => 1, priority => 60);
        zypper_call("-n in ca-certificates-suse");
    }

    my @items = split(/\s+/, $custom_pkg);
    my $alias = undef;
    my $repo_idx = 0;

    for my $item (@items) {
        if ($item =~ /^http/) {
            $repo_idx++;
            $alias = "custom_repo_$repo_idx";
            zypper_ar($item, name => $alias, no_gpg_check => 1, priority => 80);
        } else {
            if ($alias) {
                zypper_call("in --from $alias $item");
            } else {
                zypper_call("in $item");
            }
            record_info($item, script_output('rpm -qi ' . $item));
        }
    }

}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    record_info('INSTALL_RPM', get_var('INSTALL_RPM'));
    my $dpdk_default_rpm = get_var('DPDK_DEFAULT_RPM', 'dpdk dpdk-tools pciutils kernel-firmware-network');

    zypper_call("rm busybox-which") if (script_run("rpm -q busybox-which") == 0);

    install_custom_package();

    # Check for needed packages and install if missing
    my @to_install;
    for my $pkg (split(/\s+/, $dpdk_default_rpm)) {
        if (script_run("rpm -q $pkg") != 0) {
            zypper_call("in  $pkg");
        }
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
