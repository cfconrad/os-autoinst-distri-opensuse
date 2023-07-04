# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Check DAD (duplicate address detection) within dhcp4
# Maintainer:
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $ip = $self->get_ip(type => 'host');

    $self->get_from_data('wicked/dynamic_address/ifcfg-eth0', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());

    $self->do_barrier('setup');

    my $cursor = $self->get_log_cursor();
    $cursor = "-c '$cursor'" if (length($cursor) > 0);

    $self->wicked_command('ifup', $ctx->iface());
    assert_script_run('wicked ifstatus ' . $ctx->iface());

    $self->do_barrier('ifup');

    my $dup_regex = 'DHCPv4 duplicate address ipv4';
    validate_script_output("journalctl $cursor -u wickedd-dhcp4.service", qr/$dup_regex/);

    # Avoid logchecker anouncing an expected error
    my $varname = 'WICKED_CHECK_LOG_EXCLUDE_' . uc($self->{name});
    set_var($varname, get_var($varname, '') . ",wickedd-dhcp4=$dup_regex");

    $self->ping_with_timeout(type => 'host');

    $self->do_barrier('verify');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
