# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install wicked from repo
# Maintainer:

use Mojo::Base 'opensusebasetest';
use testapi;
use utils qw(zypper_call systemctl file_content_replace zypper_ar ensure_ca_certificates_suse_installed);
use version_utils 'is_sle';
use network_utils qw(iface setup_static_network);
use serial_terminal;
use main_common 'is_updates_tests';
use repo_tools 'generate_version';
use wicked::wlan;
use mm_network;
use power_action_utils 'power_action';

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal;

    assert_script_run('(cd /etc/sysconfig/ && tar -zcvf network.tar.gz network)');
    setup_static_network(ip => '10.0.2.11/15');
    assert_script_run('ping -c1 10.0.2.2');

    if (my $wicked_sources = get_var('WICKED_SOURCES')) {
        record_info('SOURCE', $wicked_sources);
        zypper_call('--quiet in automake autoconf libtool libnl-devel libnl3-devel libiw-devel dbus-1-devel pkg-config libgcrypt-devel systemd-devel git make gcc');
        my $folderName = 'wicked.git';
        my ($repo_url, $branch) = split(/#/, $wicked_sources, 2);
        assert_script_run("git config --global http.sslVerify false");
        assert_script_run("git clone '$repo_url' '$folderName'");
        assert_script_run("cd ./$folderName");
        if ($branch) {
            assert_script_run("git checkout $branch");
        }
        assert_script_run('./autogen.sh ', timeout => 600);
        assert_script_run('make ; make install', timeout => 600);
    } elsif (my $wicked_repo = get_var('WICKED_REPO')) {
        record_info('REPO', $wicked_repo);
        if ($wicked_repo =~ /suse\.de/ && script_run('rpm -qi ca-certificates-suse') == 1) {
            my $version = generate_version('_');
            zypper_call("ar --refresh http://download.suse.de/ibs/SUSE:/CA/$version/SUSE:CA.repo");
            zypper_call("in ca-certificates-suse");
        }
        zypper_ar($wicked_repo, priority => 10, params => '-n wicked_repo', no_gpg_check => 1);
        my ($resolv_options, $repo_id) = (' --allow-vendor-change  --allow-downgrade ', 'wicked_repo');
        $resolv_options = ' --oldpackage' if (is_sle('<15'));
        ($repo_id) = ($wicked_repo =~ m!(^.*/)!s) if (is_sle('<=12-sp1'));
        zypper_call("in --from $repo_id $resolv_options --force -y --force-resolution  wicked wicked-service", log => 'zypper_in_wicked.log');
        my ($zypper_in_output) = script_output('cat /tmp/zypper_in_wicked.log');
        my @installed_packages;
        for my $reg (('The following \d+ packages? (are|is) going to be upgraded:',
                'The following NEW packages? (are|is) going to be installed:',
                'The following \d+ packages? (are|is) going to be reinstalled:')) {
            push(@installed_packages, split(/\s+/, $+{packages})) if ($zypper_in_output =~ m/(?s)($reg(?<packages>.*?))(?:\r*\n){2}/);
        }
        record_info('INSTALLED', join("\n", @installed_packages));
        my @zypper_ps_progs = split(/\s+/, script_output('zypper ps  --print "%s"', qr/^\s*$/));
        for my $ps_prog (@zypper_ps_progs) {
            die("The following programm $ps_prog use deleted files") if grep { /$ps_prog/ } @installed_packages;
        }
        record_info("WARNING", "`zypper ps` return following programs:\n" . join("\n", @zypper_ps_progs), result => 'softfail') if @zypper_ps_progs;
        if (my $commit_sha = get_var('WICKED_COMMIT_SHA')) {
            validate_script_output(q(head -n 1 /usr/share/doc/packages/wicked/ChangeLog | awk '{print $2}'), qr/^$commit_sha$/);
            record_info('COMMIT', $commit_sha);
        }
    }

    wickedbase->new()->prepare_coredump();
    assert_script_run('(cd /etc/sysconfig/ &&  rm -rf network && tar -zxvf network.tar.gz)');

    power_action('reboot', textmode => 1);
    $self->wait_boot;
    $self->select_serial_terminal;

    record_info('PKG', script_output(q(rpm -qa 'wicked*' --qf '%{NAME}\n' | sort | uniq | xargs rpm -qi)));
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
