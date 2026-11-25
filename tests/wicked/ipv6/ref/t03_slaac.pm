# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: radvd
# Summary: IPv6 - SLAAC only, Managed and OtherConfig off, RDNSS, DNSSL
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;
use utils 'file_content_replace';

sub run {
    my ($self, $ctx) = @_;
    my $iface = $ctx->iface();

    # The SUT must reach the REF inside the SLAAC prefix.
    assert_script_run('ip -6 addr add ' . $self->get_ip(type => 'slaac_gw', netmask => 1) . " dev $iface");

    $self->get_from_data('wicked/radvd/radvd_03.conf', '/etc/radvd.conf');
    file_content_replace('/etc/radvd.conf',
        __IFACE__ => $iface,
        __SLAAC_PREFIX__ => $self->get_ip(type => 'slaac_prefix', netmask => 1),
        __SLAAC_DNS__ => $self->get_ip(type => 'slaac_dns'));
    $self->sync_start_of('radvd', 'radvdipv6t03');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
