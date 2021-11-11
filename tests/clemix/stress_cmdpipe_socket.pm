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
    set_var(_CHKSEL_RATE_HITS => 20_000);

    my $start_time = time;
    my $duration = get_var('CLEMIX_DURATION', 300);

    while (time - $start_time < $duration) {
        script_output("true\n", quiet => 1);
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
