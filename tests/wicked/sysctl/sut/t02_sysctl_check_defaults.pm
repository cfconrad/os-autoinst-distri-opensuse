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

    my $iface = $ctx->iface();

    $self->run_compare_test($iface, "");

    $self->run_compare_test($iface, <<EOT);
net.ipv4.conf.default.accept_redirects=1
net.ipv4.conf.all.accept_redirects=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv4.conf.all.accept_redirects=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv4.conf.lo.accept_redirects=1
net.ipv4.conf.$iface.accept_redirects=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv4.conf.all.arp_notify=1
net.ipv4.conf.default.arp_notify=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv4.conf.all.forwarding=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv4.conf.$iface.forwarding=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.all.disable_ipv6=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.lo.disable_ipv6=1
net.ipv6.conf.$iface.disable_ipv6=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=0
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.accept_dad=1
net.ipv6.conf.all.accept_dad=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.accept_dad=0
net.ipv6.conf.$iface.accept_dad=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.accept_ra=1
net.ipv6.conf.all.accept_ra=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.$iface.accept_ra=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.$iface.accept_redirects=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.addr_gen_mode=1
net.ipv6.conf.$iface.addr_gen_mode=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.all.autoconf=0
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
EOT

    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.$iface.forwarding=1
EOT
    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.default.use_tempaddr=1
net.ipv6.conf.all.use_tempaddr=1
EOT
    $self->run_compare_test($iface, <<EOT);
net.ipv6.conf.$iface.use_tempaddr=1
EOT

}

1;
