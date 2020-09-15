# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: IPv6 - Managed on, prefix length != 64, RDNSS
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use lockapi;
use testapi;

sub wait_for_user
{
    my $match = '666-CONTINUE-666';

    assert_script_run('echo "WAIT_FOR_USER_TO_CONTINUE"');
    assert_script_run(qq(echo "echo '$match' | wall" > /tmp/continue.sh  ));
    assert_script_run('chmod +x /tmp/continue.sh');
    bmwqemu::diag('WAIT_FOR_USER_TO_CONTIUE');
    wait_serial($match, no_regex => 1, timeout => 60 * 60 * 2);
}


sub run {
    my ($self, $ctx) = @_;
    wait_for_user();

    mutex_wait('radvdipv6t01');
    $self->check_ipv6($ctx);

}

sub test_flags {
    return {always_rollback => 1};
}

1;
