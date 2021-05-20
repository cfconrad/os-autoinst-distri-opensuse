# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Summary:
# Maintainer:

use Mojo::Base 'opensusebasetest';
use testapi;

sub run {
    my ($self) = @_;
    record_info("OK");
}

sub test_flags {
    return {};
}

1;
