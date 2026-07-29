# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pciutils openvswitch dpdk-tools
# Summary: Install DPDK and Open vSwitch packages
# Maintainer: cfamullaconrad@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call systemctl file_content_replace zypper_ar ensure_ca_certificates_suse_installed);
use repo_tools 'generate_version';
use registration;


sub install_custom_package
{
    my $custom_pkg = shift;
    state $repo_idx = 0;

    return unless $custom_pkg;

    if ($custom_pkg =~ /suse\.de/ && script_run('rpm -qi ca-certificates-suse') == 1) {
        my $repo_url = "https://download.opensuse.org/repositories/SUSE:/CA/";
        zypper_ar($repo_url . generate_version('_') . '/', name => 'suse_ca', no_gpg_check => 1, priority => 60);
        zypper_call("-n in ca-certificates-suse");
    }

    my @items = split(/\s+/, $custom_pkg);
    my $alias = undef;

    for my $item (@items) {
        if ($item =~ /^http/) {
            $repo_idx++;
            $alias = "custom_repo_$repo_idx";
            # the repo should be given without *.repo file
            $item =~ s/[^\/]+\.repo$//;
            zypper_ar($item, name => $alias, no_gpg_check => 1, priority => 80);
        } elsif ($item =~ /^--disable$/) {
            zypper_call('mr -d ' . $alias);
        } else {
            if ($alias) {
                zypper_call("in --from $alias $item");
            } else {
                zypper_call("in $item");
            }
            record_info($item, script_output('rpm -qi ' . $item));
        }
    }

}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my @indexes = ("", 0 .. 99);

    record_info('zypper lr', script_output('zypper lr -u'));

    for my $idx (@indexes) {
        my $remove_rpm = get_var('REMOVE_RPM' . (length($idx) ? "_$idx" : ""));
        if ($remove_rpm) {
            record_info('REMOVE_RPM', $remove_rpm);
            for my $pkg (split(/\s+/, $remove_rpm)) {
                if (script_run("rpm -q $pkg") == 0) {
                    zypper_call("rm $pkg");
                }
            }
        }
    }

    for my $idx (@indexes) {
        my $install_rpm_from_repo = get_var('INSTALL_RPM_FROM_REPO' . (length($idx) ? "_$idx" : ""));
        if ($install_rpm_from_repo) {
            record_info('INSTALL_RPM_FROM_REPO', $install_rpm_from_repo);
            install_custom_package($install_rpm_from_repo);
        }
    }

    if (get_var('ENABLE_DEBUG_REPOS', 0)) {
        assert_script_run(q(for i in $(zypper -q lr | tail -n +4 | grep Debug | awk '{ print $1 }'); do zypper mr -e $i; done));
    }

    for my $idx (@indexes) {
        my $install_rpm = get_var('INSTALL_RPM' . (length($idx) ? "_$idx" : ""));
        if ($install_rpm) {
            record_info('INSTALL_RPM', $install_rpm);
            for my $pkg (split(/\s+/, $install_rpm)) {
                if (script_run("rpm -q $pkg") != 0) {
                    zypper_call("in  $pkg");
                }
                record_info($pkg, script_output('rpm -qi ' . $pkg));
            }
        }
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
