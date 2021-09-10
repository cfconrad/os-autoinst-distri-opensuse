# SUSE's openQA tests
#
# Copyright © 2017-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: openvpn dhcp-server wicked git
# Summary: Do basic checks to make sure system is ready for wicked testing
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use Mojo::Base 'opensusebasetest';
use utils qw(zypper_call systemctl file_content_replace zypper_ar ensure_ca_certificates_suse_installed);
use version_utils 'is_sle';
use network_utils qw(iface setup_static_network);
use serial_terminal;
use main_common 'is_updates_tests';
use repo_tools 'generate_version';
use mmapi;

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal;

    assert_script_run('echo TEST');

    record_info('ID', mmapi::whoami());
}

sub test_flags {
    return {fatal => 1};
}

1;
