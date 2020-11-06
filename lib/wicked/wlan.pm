# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base class for all WLAN related tests
# Maintainer: cfamullaconrad@suse.com


package wicked::wlan;

use Mojo::Base 'wickedbase';
use utils qw(random_string);
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product);
use utils qw(zypper_call);
use testapi;

has dhcp_enabled => 0;
has eap_user     => 'tester';
has eap_password => 'test1234';

has netns_name   => 'wifi_ref';
has ref_ifc      => 'wlan0';
has ref_phy      => 'phy0';

sub ref_ip {
    my $self = shift;
    my $type = $self->dhcp_enabled ? 'wlan_dhcp' : 'wlan';
    return $self->get_ip(type => $type, is_wicked_ref => 1);
}

has sut_ifc => 'wlan1';
has sut_phy => 'phy1';

sub sut_ip {
    my $self = shift;
    my $type = $self->dhcp_enabled ? 'wlan_dhcp' : 'wlan';
    return $self->get_ip(type => $type, is_wicked_ref => 0);
}

sub sut_hw_addr {
    my $self = shift;
    $self->{sut_hw_addr} //= $self->get_hw_address($self->sut_ifc);
    return $self->{sut_hw_addr};
}

sub netns_exec {
    my ($self, $cmd, @args) = @_;
    $cmd = 'ip netns exec ' . $self->netns_name . ' ' . $cmd;
    assert_script_run($cmd, @args);
}

sub netns_output {
    my ($self, $cmd, @args) = @_;
    $cmd = 'ip netns exec ' . $self->netns_name . ' ' . $cmd;
    return script_output($cmd, @args);
}

sub ref_enable_DHCP_server {
    my $self = shift;
    $self->ref_disable_DHCP_server();
    $self->dhcp_enabled(1);
    $self->netns_exec(sprintf('dnsmasq --no-resolv --interface=%s --dhcp-range=%s,static --dhcp-host=%s,%s',
            $self->ref_ifc, $self->sut_ip, $self->sut_hw_addr, $self->sut_ip));
}

sub ref_disable_DHCP_server {
    my $self = shift;
    $self->dhcp_enabled(0);
    assert_script_run('test -e /var/run/dnsmasq.pid && kill $(cat /var/run/dnsmasq.pid) || true');
}

sub prepare {
    my $self = shift;
    $self->prepare_install_packages();
    $self->prepare_radios();
    $self->prepare_radiusd();
}

sub prepare_install_packages {
    my $self = shift;
    if (is_sle()) {
        add_suseconnect_product('PackageHub'); # needed for hopstapd
    }
    zypper_call('-q in iw hostapd wpa_supplicant dnsmasq freeradius-server freeradius-server-utils vim');
    # make sure, we do not run these deamons, as we need to run them in network namespace
    assert_script_run('systemctl disable --now dnsmasq');
    assert_script_run('systemctl disable --now radiusd');
}

sub prepare_radios {
    my $self = shift;
    assert_script_run('modprobe mac80211_hwsim radios=2');
    assert_script_run('ip netns add ' . $self->netns_name);
    assert_script_run('ip netns list');
    assert_script_run('iw dev');
    assert_script_run('iw phy ' . $self->ref_phy . ' set netns name ' . $self->netns_name);
    assert_script_run('iw dev');
    $self->netns_exec('iw dev');
    $self->netns_exec('ip link set dev lo up');
}

sub prepare_radiusd {
    my $self = shift;
    # The default installation of freeradius-server gives us a config where
    # we can authenticate with PEAP+MSCHAPv2, TLS and TTLS/PAP
    assert_script_run(sprintf(q(echo '%s ClearText-Password := "%s"' >> /etc/raddb/users),
            $self->eap_user, $self->eap_password));
    assert_script_run('(cd /etc/raddb/certs && ./bootstrap)', timeout => 300);
    assert_script_run(q(openssl rsa -in /etc/raddb/certs/client.key -out /etc/raddb/certs/client_no_pass.key -passin pass:'whatever'));
}

# Candidate for wickedbase.pm
sub get_hw_address {
    my ($self, $ifc) = @_;
    my $path   = "/sys/class/net/$ifc/address";
    my $output = script_output("test -e '$path' && cat '$path'");
    die("Interface $ifc doesn't exists") if ($output eq "");
    return $output;
}

# Candidate for wickedbase.pm
sub spurt_file {
    my ($self, $filename, $content) = @_;
    my $rand = random_string;
    script_output(qq(cat > '$filename' << 'EOT_$rand'
$content
EOT_$rand
));
}

sub hostapd_check_if_connected {
    my ($self, $sta) = @_;
    $sta //= $self->sut_hw_addr;

    my $output = $self->netns_output(sprintf(q(hostapd_cli -i '%s' sta '%s'), $self->ref_ifc, $sta));
    die("STA($sta) isn't found on that hostapd") if ($output =~ /FAIL/);
    my %opts = $output =~ /^(\S+)=(.*)$/gm;
    die 'Missing "flags" in hostapd_cli sta output' unless exists $opts{flags};
    for my $flag (qw([AUTH] [ASSOC] [AUTHORIZED])) {
        die("STA($sta) missing flag $flag") if (index($opts{flags}, $flag) == -1);
    }

    return 1;
}

sub check_ping {
    my $self = shift;

    assert_script_run('ping -c 1 -I ' . $self->sut_ifc . ' ' . $self->ref_ip);
    $self->netns_exec('ping -c 1 -I ' . $self->ref_ifc . ' ' . $self->sut_ip);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
