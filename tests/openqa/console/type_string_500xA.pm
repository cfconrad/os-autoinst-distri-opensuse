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
    record_info('FLAGS',   Dumper($self->test_flags()));
    record_info('CONSOLE', current_console());

    my $s = 'A'x(80*60);
    assert_script_run("echo $s");
    record_info("s", $s);
    type_string($s);
    save_screenshot();
}

sub test_flags {
    return {};
}

1;
