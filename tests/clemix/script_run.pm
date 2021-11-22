# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package:
# Summary:
# Maintainer:

use Mojo::Base 'opensusebasetest';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal;
    script_run("sleep 1", timeout => 10);
    script_run("sleep 1", timeout => 10, die_on_timeout=> 1);
    script_run("sleep 5", timeout => 1, die_on_timeout=> 0);
    sleep 10;
    script_run("sleep 5", timeout => 1, die_on_timeout=> 1);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
