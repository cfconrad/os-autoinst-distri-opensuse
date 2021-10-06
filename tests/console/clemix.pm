
# SUSE's openQA tests
#
# Copyright (C) 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
# Package: gcc glibc-devel gdb sysvinit-tools
# Summary: Basic GDB test. (Breakpoints/backtraces/attaching)
# - Add sdk repository if necessary
# - Install gcc glibc-devel gdb
# - Download and compile "test1.c" from datadir
#   - Using gdb, insert a breakpoint at main, run test and check
# - Download and compile "test2.c" from datadir
#   - Using gdb, run program, get a backtrace info and check
# - Download and compile "test3.c" from datadir
#   - Run test3, attach gdb to its pid, add a breakpoint and check
# Maintainer: apappas@suse.de

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils qw(zypper_call);
use version_utils qw(is_leap is_sle);

sub run {
    my $self      = shift;

    $self->select_serial_terminal;

    for my $i (1 ..  get_var('MAX_LOOPS', 1000)){
        print("X"x30 . $/);
        print($i . $/);
        my $output = script_output('w');
        print $output . $/;
        die("Missing output") if ($output !~ /load average/m);
        print("X"x30 . $/);
    }
}

1;
