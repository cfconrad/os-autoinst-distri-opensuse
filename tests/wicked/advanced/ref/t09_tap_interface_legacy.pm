# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Advanced test cases for wicked
# Test 9 : Create a tap interface from legacy ifcfg files
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self) = @_;
    record_info('Info', 'Create a TAP interface from legacy ifcfg files');
    $self->setup_openvpn_server('tap1');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
