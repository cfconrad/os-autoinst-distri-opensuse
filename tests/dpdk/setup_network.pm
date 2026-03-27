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
use network_utils qw(iface set_nic_dhcp_auto reload_connections_until_all_ips_assigned is_nm_used is_wicked_used);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Get the interface with the lowest ifindex but not LOOPBACK.
    my $iface = script_output(q(ip -o link show | awk -F': ' '$2 != "lo" {print $1, $2}' | sort -n | head -n1 | awk '{print $2}'));

    # If NICMAC is given, use interface belonging to this
    my $mac = get_var('NICMAC');
    if ($mac) {
        my $out = script_output("grep -l '$mac' /sys/class/net/*/address");
        if ($out =~ /\/([^\/]+)\/address/) {
            $iface = $1;
        }
    }
    record_info('iface', $iface);
    record_info('NetworkManager', is_nm_used() ? 'enabled' : 'disabled');
    record_info('wicked', is_wicked_used() ? 'enabled' : 'disabled');


    record_info('net', script_output('ip a s'));
    set_nic_dhcp_auto($iface);
    reload_connections_until_all_ips_assigned(nics => [$iface]);
    record_info('net', script_output("ip a s dev $iface"));
}

sub test_flags {
    return {fatal => 1};
}

1;
