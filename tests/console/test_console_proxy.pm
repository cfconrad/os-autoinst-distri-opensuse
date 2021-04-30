
# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Hyper-V bootloader with asset downloading
# Maintainer: Michal Nowak <mnowak@suse.com>

package test_console_proxy;

use Mojo::Base 'installbasetest';
use testapi;
use utils;
use Data::Dumper;

sub run {
    my $svirt               = select_console('svirt');
    my $hyperv_intermediary = select_console('hyperv-intermediary');
    my $name                = $svirt->name;


    my $console = console('svirt');

    my $cmd = 'echo "Hello World!"';
    record_info("run_cmd()",        Dumper($console->run_cmd($cmd)));
    record_info('get_cmd_output()', Dumper($console->get_cmd_output($cmd, {wantarray => 1})));

    record_info("run_cmd()",        Dumper([$console->run_cmd($cmd, wantarray =>1 )]));
}

1;
