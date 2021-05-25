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
    record_info('CONSOLE', current_console());

    select_console 'user-console';
    record_info('SELECTED CONSOLE', current_console());
    assert_script_run('echo "The live is live!"');
}

sub test_flags {
    return {};
}

1;
