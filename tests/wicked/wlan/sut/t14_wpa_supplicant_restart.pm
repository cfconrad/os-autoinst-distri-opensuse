# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test how wicked behave if wpa_supplicant is restarted unexpected
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;

has wicked_version => '>=0.6.66';
has ssid => 'Virtual WiFi PSK Secured';
has psk => 'TopSecretWifiPassphrase!';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    channel=7
    hw_mode=g
    ieee80211n=1

    ssid={{ssid}}
    wpa_passphrase={{psk}}
    wpa=2
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=CCMP
);

has ifcfg_wlan => q(
    BOOTPROTO='dhcp'
    STARTMODE='auto'

    WIRELESS_ESSID='{{ssid}}'
    WIRELESS_WPA_PSK='{{psk}}'
);

sub run {
    my $self = shift;
    my $WAIT_SECONDS = get_var("WICKED_WAIT_SECONDS", 70);
    $self->select_serial_terminal;
    return if ($self->skip_by_wicked_version());

    $self->setup_ref();
    $self->hostapd_start();

    # Setup sut
    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $self->ifcfg_wlan);
    $self->wicked_command('ifup', $self->sut_ifc);

    # Check
    $self->assert_sta_connected();
    $self->assert_connection();
    $self->wicked_command('ifstatus --verbose', $self->sut_ifc);

    record_info('STEP1', 'pkill -9 wpa_supplicant');
    assert_script_run('pkill -9 wpa_supplicant');
    $self->retry(sub {
            assert_script_run(sprintf(q(test "up" != "$(wicked ifstatus --brief %s | awk '{print $2}')"), $self->sut_ifc));
    });

    # Reenable the wpa_supplicant
    assert_script_run('systemctl start wpa_supplicant');
    $self->retry(sub {
            assert_script_run(sprintf(q(test "up" == "$(wicked ifstatus --brief %s | awk '{print $2}')"), $self->sut_ifc));
    });


    record_info('STEP2', 'systemctl restart wpa_supplicant');
    assert_script_run('systemctl restart wpa_supplicant');
    sleep 5;    # Just wait some time. So the interface has time to goes down.
    $self->retry(sub {
            assert_script_run(sprintf(q(test "up" == "$(wicked ifstatus --brief %s | awk '{print $2}')"), $self->sut_ifc));
    });

    # Check
    $self->assert_sta_connected();
    $self->assert_connection();
    $self->wicked_command('ifstatus --verbose', $self->sut_ifc);
}

1;
