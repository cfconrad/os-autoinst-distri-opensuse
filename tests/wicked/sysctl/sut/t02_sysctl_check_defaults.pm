# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test WiFi setup with wicked (WPA-PSK with DHCP)
#          If a connection is established, the AP will went down and a other
#          SSID appear. Check if the wpa_supplicant also connect to the new one.
#
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wickedbase';
use testapi;
use List::Util qw(uniq);
use Mojo::JSON;
use Mojo::File qw(path);
use serial_terminal;

sub get_diff {
    my ($t1, $t2, $name1, $name2, $allow_diff) = @_;
    my %v1 = ($t1 =~ /^([^\s=]+)\s+=\s+([^\s]+)$/gm);
    my %v2 = ($t2 =~ /^([^\s=]+)\s+=\s+([^\s]+)$/gm);
    my @diff;

    for my $k (sort keys %v1) {
        if (exists $v2{$k}) {
            if ($v2{$k} ne $v1{$k} && !(exists $allow_diff->{$k} && $allow_diff->{$k} eq $v2{$k})) {
                push @diff, "$k differ got  $name2 has '$v2{$k}' expected '$v1{$k}' as $name1";
            }
        } else {
            push @diff, "$k missing in $name2";
        }
        delete $v2{$k};
    }
    for my $k (sort keys %v2) {
        push @diff, "$k missing in $name1";
    }

    return join("\n", @diff);
}

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal();

    return if $self->skip_by_wicked_version('>=0.6.68');

    # reboot first, so we do get the lastes bootup with current wicked version!!
    serial_terminal::reboot();

    my @conf_ipv6 = qw(disable_ipv6 autoconf use_tempaddr accept_ra accept_dad accept_redirects addr_gen_mode stable_secret);
    my @conf_ipv4 = qw(arp_notify accept_redirects);
    my $dummy0 = 'dummy0';
    my @interfaces = ('lo', $ctx->iface(), $dummy0);

    $self->get_from_data('wicked/ifcfg/ifcfg-eth0-hotplug-static', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->get_from_data('wicked/ifcfg/dummy0', "/etc/sysconfig/network/ifcfg-$dummy0");
    $self->wicked_command('ifreload', 'all');

    my @u = uniq(@conf_ipv6, @conf_ipv4);
    my $cmd = <<EOT;
        for cfg in @u; do
            echo "############### \$cfg";
            sysctl -a | grep "\.\$cfg " || true;
        done
EOT

    my $out_wicked = script_output($cmd);
    $self->record_console_test_result("Sysctl Wicked", $out_wicked, result => 'ok');

    mkdir "ulogs";
    path(sprintf('ulogs/%s_%s@%s_sysctl_wicked.txt', get_var('DISTRI'), get_var('VERSION'), get_var('ARCH')))->spurt($out_wicked);

    script_run('systemctl disable --now wicked', die_on_timeout => 1);
    script_run('systemctl disable --now wickedd', die_on_timeout => 1);
    serial_terminal::reboot();

    assert_script_run('ip link add type dummy');
    my $out_native = script_output($cmd);

    $self->record_console_test_result("Sysctl Native", $out_native, result => 'ok');
    path(sprintf('ulogs/%s_%s@%s_sysctl_native.txt', get_var('DISTRI'), get_var('VERSION'), get_var('ARCH')))->spurt($out_native);

    # Wicked set `ipv4.arp_notify = 1` by default.
    my $except_diff = {'net.ipv4.conf.' . $ctx->iface() . '.arp_notify' => 1};
    my $diff = get_diff($out_native, $out_wicked, 'native', 'wicked', $except_diff);
    die("Sysctl of native and wicked defaults are different!\n" . $diff . "\n") if $diff;
}
1;
