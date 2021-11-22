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
    select_console('sut');
    my $out = script_output('find /');
    record_info('UH', $out);
}

1;
