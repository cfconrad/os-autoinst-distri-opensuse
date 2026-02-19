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
}

sub test_flags {
    return {fatal => 1};
}

1;


