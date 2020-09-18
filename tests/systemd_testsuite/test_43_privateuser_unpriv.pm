# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run test executed by TEST-43-PRIVATEUSER-UNPRIV from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base 'systemd_testsuite_test';
use warnings;
use strict;
use testapi;

sub pre_run_hook {
    my ($self) = @_;
    #prepare test
    $self->testsuiteprepare('TEST-43-PRIVATEUSER-UNPRIV');
}

sub run {
    #run test
    assert_script_run 'cd /usr/lib/systemd/tests';
    assert_script_run './run-tests.sh TEST-43-PRIVATEUSER-UNPRIV --run 2>&1 | tee /tmp/testsuite.log', 600;
    assert_script_run 'grep "PASS: ...TEST-43-PRIVATEUSER-UNPRIV" /tmp/testsuite.log';
    script_run './run-tests.sh TEST-42-EXECSTOPPOST --clean';
}

sub test_flags {
    return {always_rollback => 1};
}


1;
