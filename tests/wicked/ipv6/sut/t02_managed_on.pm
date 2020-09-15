# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: IPv6 - Managed on, prefix length != 64
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
#             Jose Lausuch <jalausuch@suse.com>
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base 'wickedbase';
use strict;
use warnings;
use lockapi;

sub run {
    my ($self, $ctx) = @_;

    assert_script_run('ip link set dev eth0 up');
    my $responses = 0;
    while ($responses < 1){
        my $out = script_output('arping -D -I eth0 10.0.2.2', proceed_on_failure => 1);
        record_info('OUT', $out);
        if ($out =~ m/Received\s+(\d+)\s+response/){
            $responses = $1;
        }
    }


    mutex_wait('radvdipv6t02');
    $self->check_ipv6($ctx);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
