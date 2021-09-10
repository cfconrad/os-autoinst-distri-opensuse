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
use testapi;
use mmapi;

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal;

    assert_script_run('echo TEST');

    record_info('ID', get_current_job_id());
}

sub test_flags {
    return {fatal => 1};
}

1;
