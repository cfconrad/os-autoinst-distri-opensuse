# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Stress test the virtio serial terminal with long output.
# Maintainer: cfamullaconrad@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use Mojo::Util qw(sha1_sum trim);
use Mojo::File 'path';
use power_action_utils 'power_action';

sub run {
    my $self    = shift;
    my $console = $self->select_serial_terminal;

    my $out = script_output("echo 'HELLO WORLD'");
    die("OOops $out") if ($out ne 'HELLO WORLD');

    select_console("root-console");
    power_action('reboot', textmode => 1);
    $self->wait_boot();
    select_console("root-console");
    $out = script_output("echo 'HELLO WORLD'");
    die("OOops $out") if ($out ne 'HELLO WORLD');

    $self->select_serial_terminal;
    $out = script_output("echo 'HELLO WORLD'");
    die("OOops $out") if ($out ne 'HELLO WORLD');
}

sub test_flags {
    return {always_rollback => 1};
}


1;

=head1 Configuration
Testing virtio or svirt serial console.

NOTE: test is using C<select_serial_terminal()> therefore
VIRTIO_CONSOLE resp. SERIAL_CONSOLE must *not* be set to 0
(otherwise root-console will be used).

=head2 Example

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_sdk_installed.qcow2
VIRTIO_CONSOLE_TEST=1

=head2 VIRTIO_CONSOLE_TEST_FILESIZE

File size which will be used to C<cat> to get the output from. Default is 1mb.

=cut
