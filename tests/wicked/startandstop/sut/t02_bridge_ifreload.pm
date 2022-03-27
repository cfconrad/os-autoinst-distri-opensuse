# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: Bridge - ifreload
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    my $config = '/etc/sysconfig/network/ifcfg-br0';
    my $dummy = '/etc/sysconfig/network/ifcfg-dummy0';
    record_info('Info', 'Bridge - ifreload');
    $self->get_from_data('wicked/ifcfg/br0', $config);
    $self->get_from_data('wicked/ifcfg/dummy0', $dummy);
    $self->setup_bridge($config, $dummy, 'ifreload');
    eval {
        $self->get_test_result('br0');
    };
    if ($@) {
        assert_script_run('ip a s');
        assert_script_run('wicked --log-level debug --debug all ifstatus --verbose all');
        print("WE HIT THE ROAD JACK!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
        sleep;
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
