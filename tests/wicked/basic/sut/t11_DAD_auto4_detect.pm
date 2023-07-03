# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked wicked-service
# Summary: Check DAD (duplicate address detection) within auto4
# Maintainer:
#             Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;

sub run {
    my ($self, $ctx) = @_;
    my $ip = $self->get_ip(type => 'host');

    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $ctx->iface(), <<EOT);
STARTMODE=auto
BOOTPROTO=auto4
EOT

    $self->do_barrier('setup');
    
    my $cursor = $self->get_log_cursor();
    $cursor = "-c '$cursor'" if (length($cursor) > 0);

    $self->wicked_command('ifup', $ctx->iface());
    assert_script_run('wicked ifstatus ' . $ctx->iface());

    $self->do_barrier('ifup');

    my $dup_regex = 'autoip4 address conflict ipv4 169.254';
    validate_script_output("journalctl $cursor -u wickedd-auto4.service", qr/$dup_regex/);

    die("Currenty ip doesn't match IPv4 AUTO-IP range") unless $self->get_current_ip($ctx->iface()) =~ /^169\.254\./;
    assert_script_run('ping -c 1 169.254.0.1');

    $self->do_barrier('verify');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
