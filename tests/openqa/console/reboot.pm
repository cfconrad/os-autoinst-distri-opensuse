# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Summary:
# Maintainer:

use Mojo::Base 'opensusebasetest';
use testapi;
use Data::Dumper;
use power_action_utils;

sub run {
    my ($self) = @_;
    record_info('FLAGS', Dumper($self->test_flags()));

    power_action('reboot');
}

sub test_flags {
    return {};
}

1;
