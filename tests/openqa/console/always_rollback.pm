# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Summary:
# Maintainer:

use Mojo::Base 'opensusebasetest';
use testapi;
use Data::Dumper;

sub run {
    my ($self) = @_;
    record_info('FLAGS', Dumper($self->test_flags()));
}

sub test_flags {
    return {always_rollback => 1};
}

1;
