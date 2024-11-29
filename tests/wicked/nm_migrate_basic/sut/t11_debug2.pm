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

    record_info("SIMPLY NOTHING!!");
}

1;
