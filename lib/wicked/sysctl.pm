# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for all sysctl tests
# Maintainer: cfamullaconrad@suse.com


package wicked::sysctl;
use Mojo::Base 'wickedbase';
use testapi;
use Mojo::File qw(path);

sub get_diff {
    my ($t1, $t2, $name1, $name2, $allow_diff) = @_;
    my %v1 = ($t1 =~ /^([^\s=]+)\s+=\s+([^\s]+)$/gm);
    my %v2 = ($t2 =~ /^([^\s=]+)\s+=\s+([^\s]+)$/gm);
    my @diff;

    for my $k (sort keys %v1) {
        if (exists $v2{$k}) {
            if ($v2{$k} ne $v1{$k} && !(exists $allow_diff->{$k} && $allow_diff->{$k} eq $v2{$k})) {
                push @diff, "$k differ got $name2 has '$v2{$k}' expected '$v1{$k}' as $name1";
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


=head2 run_compare_test
This function collects compare the sysctl outcome with and without wicked.
Sequence:
  * Create ethernet interface with simple static config
  * Create dummy interface config
  * Run: wicked ifreload all
  * Collect all sysctl's
  * Disable wicked and wickedd service
  * Reboot
  * Create ethernet interface with ip tool
  * Create dummy interface with ip tool
  * Collect all sysctl
  * Compare

=cut

sub run_compare_test {
    my ($self, $ctx, $allow_diff) = @_;
    my @conf_ipv6 = qw(disable_ipv6 autoconf use_tempaddr accept_ra accept_dad accept_redirects addr_gen_mode stable_secret forwarding);
    my @conf_ipv4 = qw(arp_notify accept_redirects forwarding);
    my $dummy0 = 'dummy0';
    my @interfaces = ('lo', $ctx->iface(), $dummy0);

    my $cfg = <<EOT;
STARTMODE='auto'
BOOTPROTO='static'
EOT

    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $ctx->iface(), $cfg);
    $self->write_cfg("/etc/sysconfig/network/ifcfg-$dummy0", $cfg);
    $self->wicked_command('ifreload', 'all');

    my $cmd = <<EOT;
        for cfg in @conf_ipv4; do
            echo "############### ipv4::\$cfg";
            sysctl -a | grep ipv4 | grep "\.\$cfg " || true;
        done
        for cfg in @conf_ipv6; do
            echo "############### ipv6::\$cfg";
            sysctl -a | grep ipv6 | grep "\.\$cfg " || true;
        done
EOT

    my $out_wicked = script_output($cmd);
    $self->record_console_test_result("Sysctl Wicked", $out_wicked, result => 'ok');

    mkdir "ulogs";
    path(sprintf('ulogs/%s_%s@%s_sysctl_wicked.txt',
            get_var('DISTRI'), get_var('VERSION'), get_var('ARCH')))->spew($out_wicked);

    # Disable wicked and reboot to get "systemd-sysctl" defaults
    script_run('systemctl disable --now wicked', die_on_timeout => 1);
    script_run('systemctl disable --now wickedd', die_on_timeout => 1);
    $self->reboot();

    assert_script_run('modprobe dummy numdummies=0');
    assert_script_run('ip link add dummy0 type dummy');
    my $out_native = script_output($cmd);

    $self->record_console_test_result("Sysctl Native", $out_native, result => 'ok');
    path(sprintf('ulogs/%s_%s@%s_sysctl_native.txt',
            get_var('DISTRI'), get_var('VERSION'), get_var('ARCH')))->spew($out_native);

    # Wicked set `ipv4.arp_notify = 1` by default.
    my $diff = get_diff($out_native, $out_wicked, 'native', 'wicked', $allow_diff);
    die("Sysctl of native and wicked defaults are different!\n" . $diff . "\n") if $diff;
}

1;
