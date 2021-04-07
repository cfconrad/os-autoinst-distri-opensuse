# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: openssh
# Summary: This tests will establish the tunnel and enable the SSH interactive console
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use publiccloud::ssh_interactive;
use testapi;
use utils;
use publiccloud::utils "select_host_console";

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    # Establish the tunnel (it will stay active in foreground and occupy this console!)
    select_console('tunnel-console');
    ssh_interactive_tunnel($args->{my_instance});

    # Switch to root-console and SSH to the instance
    # every other loaded test must stay in root-console
    select_console 'root-console';

    # Fix serial terminal to use TUNNELED stuff
    $self->select_serial_terminal();
    ssh_interactive_join();

}

1;
