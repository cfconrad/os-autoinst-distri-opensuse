# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked 2 NetworkManger migration
# Summary: Set up static addresses from legacy ifcfg files
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wicked::nm_migrate';
use testapi;

sub run {
    my ($self, $ctx) = @_;

    my $cfg = '/etc/sysconfig/network/ifcfg-' . $ctx->iface();
    $self->get_from_data('wicked/static_address/ifcfg-eth0', $cfg);
    record_info("ifcfg", script_output("cat '$cfg'"));
    $self->wicked_command('ifup', $ctx->iface());

    $self->migrate();
    $self->assert_nm_state(ping_ip => $self->get_remote_ip(type => 'host'), iface => $ctx->iface());
}

1;
