# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openvpn wicked
# Summary: OpenVPN tunnel - ifdown
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self) = @_;
    record_info('Info', 'OpenVPN tunnel - ifdown/ifup');
    $self->setup_openvpn_server('tun1');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
