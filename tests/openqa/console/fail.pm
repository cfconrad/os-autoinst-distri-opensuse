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
    die("FAIL now!");
}

sub test_flags {
    return {};
}

1;
