# SUSE's openSLP regression test
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

use Mojo::Base "opensusebasetest";
use testapi;

sub run {
    my ($self) = @_;

    my $seconds = get_var(CONSOLE_SLEEP_SECONDS => 900);

    say "SLEEP for $seconds";
    while($seconds > 0) {
        $seconds--;
        say "$seconds left...";
        sleep 1;
    }
}

1;

