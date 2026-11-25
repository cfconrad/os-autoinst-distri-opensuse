# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: wicked
# Summary: IPv6 - SLAAC only, Managed and OtherConfig off, RDNSS, DNSSL
#
# The REF sends router advertisements with the M and O flags off and one
# autonomous /64 prefix. The SUT uses BOOTPROTO='auto6'. The test checks:
#  - the RA content, as rdisc6 sees it,
#  - one global, dynamic, not tentative address from the SLAAC prefix,
#  - the address lifetimes from the RA,
#  - the EUI-64 interface identifier, if addr_gen_mode is eui64,
#  - wicked marks the address as SLAAC ([auto]) and no address as DHCPv6 ([dhcp]),
#  - the prefix route and the default route from the RA,
#  - IPv6 connectivity to the REF,
#  - RDNSS and DNSSL in /etc/resolv.conf.
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base 'wickedbase';
use testapi;
use lockapi;

# match data/wicked/radvd/radvd_03.conf
use constant {
    RA_VALID_LFT => 3600,
    RA_PREFERRED_LFT => 2400,
    RA_DNSSL => 'slaac.example.net',
};

sub fail_check {
    my ($self, $title, $msg) = @_;
    record_info($title, $msg, result => 'fail');
    $self->{slaac_errors}++;
}

# Return the expected EUI-64 address for $prefix (e.g. 'fd00:dead:beef:5a0c')
# and the MAC address $mac.
sub eui64_address {
    my ($prefix, $mac) = @_;
    my @b = map { hex } split(/:/, $mac);
    die("Invalid MAC address '$mac'") unless @b == 6;
    return sprintf('%s:%02x%02x:%02xff:fe%02x:%02x%02x',
        $prefix, $b[0] ^ 0x02, $b[1], $b[2], $b[3], $b[4], $b[5]);
}

sub run {
    my ($self, $ctx) = @_;
    my $iface = $ctx->iface();
    my $prefix = $self->get_ip(type => 'slaac_prefix');    # 'fd00:dead:beef:5a0c::'
    my $gw = $self->get_ip(type => 'slaac_gw');
    my $dns = $self->get_ip(type => 'slaac_dns');
    (my $prefix64 = $prefix) =~ s/::$//;    # 'fd00:dead:beef:5a0c'
    my $output;
    $self->{slaac_errors} = 0;

    mutex_wait('radvdipv6t03');

    # Remove the static setup from before_test, then use SLAAC only.
    $self->wicked_command('ifdown', $iface);
    $self->get_from_data('wicked/ifcfg/ipv6_slaac', '/etc/sysconfig/network/ifcfg-' . $iface);
    $self->wicked_command('ifup', $iface);

    # Check the RA content.
    $output = script_output("rdisc6 $iface");
    record_info('rdisc6', $output);
    $self->fail_check('RA M flag', 'Managed flag is not off') unless $output =~ /Stateful address conf\.\s*:\s*No/;
    $self->fail_check('RA O flag', 'OtherConfig flag is not off') unless $output =~ /Stateful other conf\.\s*:\s*No/;
    $self->fail_check('RA prefix', "Prefix $prefix/64 is missing") unless $output =~ /Prefix\s*:\s*\Q$prefix\E\/64/;
    $self->fail_check('RA RDNSS', "RDNSS $dns is missing") unless $output =~ /Recursive DNS server\s*:\s*\Q$dns\E/;

    # Wait for the SLAAC address. DAD must be complete.
    # The flags after "scope global" are checked one by one, as iproute2
    # prints them in a fixed order (e.g. "tentative dynamic mngtmpaddr").
    my $addr_re = qr/inet6 (\Q$prefix64\E:[0-9a-f:]+)\/64 scope global([^\n]*)/;
    my $slaac_addr;
    for (1 .. 12) {
        $output = script_output("ip -6 addr show dev $iface scope global");
        while ($output =~ /$addr_re/g) {
            my $addr = $1;
            my $flags_str = $2;
            my %flags = map { $_ => 1 } split(' ', $flags_str);
            next unless $flags{dynamic};
            # skip if one of the flags exists
            next if grep { $flags{$_} } qw(temporary tentative dadfailed deprecated);
            $slaac_addr = $addr;
            last;
        }
        last if $slaac_addr;
        record_info('Waiting', 'Waiting for SLAAC address');
        sleep 5;
    }
    die("No global dynamic SLAAC address from $prefix/64 on $iface:\n$output\n") unless $slaac_addr;
    record_info('SLAAC address', $slaac_addr);

    # Check the lifetimes. The kernel decrements them, so they must be
    # not more than the values in the RA, and not "forever".
    $output = script_output("ip -6 addr show dev $iface to $slaac_addr/128");
    if ($output =~ /valid_lft (\d+)sec preferred_lft (\d+)sec/) {
        my ($valid, $preferred) = ($1, $2);
        $self->fail_check('valid_lft', "valid_lft $valid is not in range 1.." . RA_VALID_LFT)
          unless $valid > 0 && $valid <= RA_VALID_LFT;
        $self->fail_check('preferred_lft', "preferred_lft $preferred is not in range 1.." . RA_PREFERRED_LFT)
          unless $preferred > 0 && $preferred <= RA_PREFERRED_LFT;
    } else {
        $self->fail_check('Lifetime', "SLAAC address has no finite lifetimes:\n$output");
    }

    # Check the interface identifier if the kernel uses EUI-64.
    my $gen_mode = script_output("cat /proc/sys/net/ipv6/conf/$iface/addr_gen_mode");
    if ($gen_mode eq '0') {
        my $mac = script_output("cat /sys/class/net/$iface/address");
        my $expected = eui64_address($prefix64, $mac);
        $output = script_output("ip -6 -o addr show dev $iface to $expected/128");
        $self->fail_check('EUI-64', "Expected EUI-64 address $expected is missing") unless $output =~ /inet6/;
    } else {
        record_info('EUI-64', "addr_gen_mode is $gen_mode, EUI-64 check is not applicable");
    }

    # Check the address owner. wicked ifstatus shows it in brackets after
    # the address, e.g. "addr: ipv6 fd00:dead:beef:5a0c:.../64 [auto]".
    # The SLAAC address must be "[auto]". With M and O off, no IPv6 address
    # must be "[dhcp]". The positive check makes sure that the output format
    # is as expected, thus the negative check is not void.
    $output = script_output("wicked ifstatus $iface");
    record_info('wicked ifstatus', $output);
    $self->fail_check('Address owner', "SLAAC address $slaac_addr is not marked as [auto]:\n$output")
      unless $output =~ /^\s*addr:\s+ipv6 \Q$slaac_addr\E\/64 \[auto\]/m;
    $self->fail_check('DHCPv6', "Unexpected DHCPv6 address:\n$output")
      if $output =~ /^\s*addr:\s+ipv6 \S+ \[dhcp\]/m;

    # Check the routes.
    $output = script_output("ip -6 -o route show dev $iface");
    record_info('ip -6 route', $output);
    $self->fail_check('Prefix route', "Route for $prefix/64 is missing") unless $output =~ /^\Q$prefix\E\/64 /m;
    $self->fail_check('Default route', 'Default route from RA is missing')
      unless $output =~ /^default via fe80:[0-9a-f:]+ .*proto ra/m;

    $self->ping_with_timeout(ip => $gw, ip_version => 'v6', timeout => 12);

    # Check RDNSS and DNSSL in resolv.conf.
    my $dns_ok = 0;
    for (1 .. 12) {
        $output = script_output('cat /etc/resolv.conf');
        record_info('resolv.conf', $output);
        if ($output =~ /^nameserver \Q$dns\E$/m && $output =~ /^search .*\b\Q${\RA_DNSSL}\E\b/m) {
            $dns_ok = 1;
            last;
        }
        record_info('Waiting', 'Waiting for RDNSS and DNSSL in resolv.conf');
        sleep 5;
    }
    $self->fail_check('DNS', "RDNSS $dns or DNSSL " . RA_DNSSL . " is missing in resolv.conf:\n$output") unless $dns_ok;

    record_info('ifstatus', script_output("wicked ifstatus --verbose $iface", proceed_on_failure => 1));
    die("There were $self->{slaac_errors} errors during SLAAC test") if $self->{slaac_errors};
}

sub test_flags {
    return {always_rollback => 1};
}

1;
