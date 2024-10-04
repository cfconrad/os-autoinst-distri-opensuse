# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Compare sysctl values if wicked is loaded and not.
#          when disable_ipv6 is set
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

    $self->write_cfg("/etc/sysctl.conf", <<EOT);
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOT
    $self->reboot();

    $self->run_compare_test($ctx);
}

1;
