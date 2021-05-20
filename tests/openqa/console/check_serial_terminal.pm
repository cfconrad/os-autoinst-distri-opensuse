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

    $self->select_serial_terminal();

    assert_script_run('echo "The live is live!"');
}

sub test_flags {
    return {};
}

1;
