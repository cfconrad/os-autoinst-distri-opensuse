# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Compare sysctl values if wicked is loaded and not. And do not allow
#          differences which are not expected, (e.g. arp_notify=1 which is set
#          by wicked, if SEND_GRATUITOUS_ARP=auto).
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::sysctl';
use testapi;
use serial_terminal 'select_serial_terminal';
use List::Util qw(uniq);
use Mojo::File qw(path);

sub run {
    my ($self, $ctx) = @_;
    select_serial_terminal();

    return if $self->skip_by_wicked_version('>=0.6.68');

    my $allow_diff = {'net.ipv4.conf.' . $ctx->iface() . '.arp_notify' => 1};

    $self->run_compare_test($ctx, $allow_diff);
}

1;
