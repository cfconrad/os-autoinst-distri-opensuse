# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Stress test the virtio serial terminal for debugging OpenQA and QEMU
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use serial_terminal;


sub run {
    my ($self, $args) = @_;
    if ($args->{serial_console_name}){
        $self->select_serial_terminal;
        add_serial_console($args->{serial_console_name});
    }
}

1;
