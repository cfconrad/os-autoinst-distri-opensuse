# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Advanced test cases for wicked
# Test 21: Create VXLAN tunnel and use ping to validate connection
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;

    my $remote_ip = $self->get_remote_ip(type => 'host');
    my $local_ip = $self->get_ip(type => 'host', netmask => 1);
    my $tunl_ip = $self->get_ip(type => 'vxlan', netmask => 1);

    $self->write_cfg('/etc/sysconfig/network/ifcfg-vxlan1', <<EOT);
STARTMODE=auto
BOOTPROTO=static
LLADDR={{unique_macaddr}}
IPADDR=$tunl_ip
VXLAN=yes
VXLAN_ID=100
VXLAN_REMOTE_IP=$remote_ip
EOT

    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $ctx->iface(), <<EOT);
STARTMODE=auto
BOOTPROTO=static
IPADDR=$local_ip
EOT

    $self->wicked_command('ifup', 'all');

    $self->ping_with_timeout(type => 'vxlan', interface => 'vxlan1', count_success => 30, timeout => 4);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
