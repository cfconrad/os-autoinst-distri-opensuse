# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Teaming, Active-Backup Arp Ping
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;
use serial_terminal;


sub run {
    my ($self, $ctx) = @_;
    record_info('INFO', 'Teaming, Active-Backup Arp Ping');
    #$self->setup_team('ab-arp_ping', $ctx->iface(), $ctx->iface2());
    #$self->validate_interfaces('team0', $ctx->iface(), $ctx->iface2(), 0);
    #$self->check_fail_over('team0');
    #$self->ping_with_timeout(type => 'host', interface => 'team0', count_success => 30, timeout => 4);
    my $sz = get_var('CLEMIX_SZ', 1);
    my $fname = "foo_${sz}m.blob";
    assert_script_run(sprintf('dd of=/tmp/%s if=/dev/urandom bs=$((1024*1024)) count=%d', $fname, $sz);
    eval {
        select_console('root-virtio-terminal1') if (get_var('VIRTIO_CONSOLE_NUM', 1) > 1);
        upload_file('/tmp/'. $fname, $fname);
    };
    $self->select_serial_terminal();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
