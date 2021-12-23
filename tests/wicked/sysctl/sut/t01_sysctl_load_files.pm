# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: sysctl --system and wicked should have the same order in reading
#          sysctl configuration files. This test use debug output of wicked and
#          sysctl and check the load order sysctl-configuration files.
#          With procps-ng >=3.3.17 wicked isn't compatible anymore. This apply
#          to tumbleweed. But sle's "procps-ng" and wicked should be compat
#          otherwise we should file a bug.
#
# Maintainer: cfamullaconrad@suse.com

use Mojo::Base 'wickedbase';
use testapi;
use autotest ();
use version_utils qw(is_sle check_version);

our $wicked_show_config = 'wicked --log-level debug --debug all  show-config all';

sub wicked_get_file_order {
    my $out = script_output($wicked_show_config . ' |& grep "Reading sysctl file"');
    my @files = ($out =~ m/file\s+'([^']+)'/g);
    return @files;
}

sub wicked_get_file_errors {
    my $out = script_output($wicked_show_config . ' |& grep "Cannot open"');
    my @files = ($out =~ m/Cannot open\s+'([^']+)'/g);
    return @files;
}

sub sysctl_get_file_order {
    my $out = script_output('sysctl  --system  | grep Applying', proceed_on_failure => 1);
    my @files = ($out =~ m/Applying\s+(.+)\s+\.\.\./g);
    return @files;
}

sub check_load_order {
    my $exp_order = shift;
    my @sysctl = $exp_order ? @$exp_order : sysctl_get_file_order();
    my @wicked = wicked_get_file_order;

    unless (join(',', @sysctl) eq join(',', @wicked)) {
        die("Sysctl and wicked load the files in different order\n" .
              "sysctl: @sysctl\n" .
              "wicked: @wicked\n");
    }
}

sub check_agains_sysctl {
    my ($self, $ctx) = @_;

    my @sysctl_d = qw(
      /run/sysctl.d
      /etc/sysctl.d
      /usr/local/lib/sysctl.d
      /usr/lib/sysctl.d
      /lib/sysctl.d
    );
    check_load_order();

    # Check order of files in sysctl.d directories
    for my $dir (@sysctl_d) {
        assert_script_run("mkdir -p $dir && touch $dir/20-test.conf");
        check_load_order();
    }
    for my $dir (reverse @sysctl_d) {
        assert_script_run("mkdir -p $dir && touch $dir/21-test.conf");
        check_load_order();
    }

    for my $dir (@sysctl_d) {
        assert_script_run("rm $dir/20-test.conf");
        check_load_order();
    }

    for my $dir (reverse @sysctl_d) {
        assert_script_run("rm $dir/21-test.conf");
        check_load_order();
    }

    # Check SUSE special ifsysctl files
    my @sysctl_order = sysctl_get_file_order;
    my $sysctl_f1 = '/etc/sysconfig/network/ifsysctl';
    my $sysctl_f2 = '/etc/sysconfig/network/ifsysctl-' . $ctx->iface();
    assert_script_run("touch $sysctl_f1");
    check_load_order([@sysctl_order, $sysctl_f1]);

    assert_script_run("touch $sysctl_f2");
    check_load_order([@sysctl_order, $sysctl_f1, $sysctl_f2]);

    assert_script_run("rm $sysctl_f1");
    check_load_order([@sysctl_order, $sysctl_f2]);

    assert_script_run("rm $sysctl_f2");
    check_load_order();

    # Check broken symlinks
    for my $dir (reverse @sysctl_d) {
        my $file = "$dir/20-test.conf";
        assert_script_run("mkdir -p $dir && ln -s /I_do_not_exists $file");
        check_load_order();
        die("Missing broken '$file' in logs") unless grep { $_ eq $file } wicked_get_file_order();
        die("Missing error message for '$file'") unless grep { $_ eq $file } wicked_get_file_errors();
    }

    # Exceptional behavior for /etc/sysctl.conf, it is silently ignored
    my $file = "/etc/sysctl.conf";
    assert_script_run("rm $file");
    assert_script_run("ln -s /I_do_not_exists $file");
    check_load_order();
    die("Wrongly showing broken '$file' in logs") if grep { $_ eq $file } wicked_get_file_order();
    die("Wrongly showing missing '$file' in logs") if grep { $_ eq $file } wicked_get_file_errors();
}

sub check_static {
    my ($self, $ctx) = @_;

    my $kver = script_output('uname -r');
    my $boot_sysctl = '/boot/sysctl.conf-' . $kver;
    my @steps = (
        {
            check => [$boot_sysctl, qw(/usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /run/sysctl.d && touch /run/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /etc/sysctl.d && touch /etc/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /usr/local/lib/sysctl.d && touch /usr/local/lib/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /usr/lib/sysctl.d && touch /usr/lib/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /lib/sysctl.d && touch /lib/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /lib/sysctl.d && touch /lib/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /lib/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /usr/lib/sysctl.d && touch /usr/lib/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /usr/lib/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /usr/local/lib/sysctl.d && touch /usr/local/lib/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /usr/local/lib/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /etc/sysctl.d && touch /etc/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /etc/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /run/sysctl.d && touch /run/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /run/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/etc/sysctl.d/20-test.conf /run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /etc/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/usr/local/lib/sysctl.d/20-test.conf /run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /usr/local/lib/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/usr/lib/sysctl.d/20-test.conf /run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /usr/lib/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/lib/sysctl.d/20-test.conf /run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /lib/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /lib/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /usr/lib/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /usr/local/lib/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /etc/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/21-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /run/sysctl.d/21-test.conf',
            check => [$boot_sysctl, qw(/usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'touch /etc/sysconfig/network/ifsysctl',
            check => [$boot_sysctl, qw(/usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf /etc/sysconfig/network/ifsysctl)]
        },
        {
            cmd => 'touch /etc/sysconfig/network/ifsysctl-' . $ctx->iface(),
            check => [$boot_sysctl, qw(/usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf /etc/sysconfig/network/ifsysctl), '/etc/sysconfig/network/ifsysctl-' . $ctx->iface()]
        },
        {
            cmd => 'rm /etc/sysconfig/network/ifsysctl',
            check => [$boot_sysctl, qw(/usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf), '/etc/sysconfig/network/ifsysctl-' . $ctx->iface()]
        },
        {
            cmd => 'rm /etc/sysconfig/network/ifsysctl-' . $ctx->iface(),
            check => [$boot_sysctl, qw(/usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /lib/sysctl.d && ln -s /I_do_not_exists /lib/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/lib/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /usr/lib/sysctl.d && ln -s /I_do_not_exists /usr/lib/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/usr/lib/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /usr/local/lib/sysctl.d && ln -s /I_do_not_exists /usr/local/lib/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/usr/local/lib/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /etc/sysctl.d && ln -s /I_do_not_exists /etc/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/etc/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'mkdir -p /run/sysctl.d && ln -s /I_do_not_exists /run/sysctl.d/20-test.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf /etc/sysctl.conf)]
        },
        {
            cmd => 'rm /etc/sysctl.conf && ln -s /I_do_not_exists /etc/sysctl.conf',
            check => [$boot_sysctl, qw(/run/sysctl.d/20-test.conf /usr/lib/sysctl.d/50-default.conf /usr/lib/sysctl.d/51-network.conf /etc/sysctl.d/70-yast.conf /usr/lib/sysctl.d/99-sysctl.conf)]
        }
    );

    for my $step (@steps) {
        assert_script_run($step->{cmd}) if ($step->{cmd});
        check_load_order($step->{check});
    }
}

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal();

    return if $self->skip_by_wicked_version('>=0.6.68');

    $self->get_from_data('wicked/ifcfg/ifcfg-eth0-hotplug-static', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->wicked_command('ifreload', 'all');
    $self->check_static($ctx);

    # Because of this commit https://gitlab.com/procps-ng/procps/-/commit/5da3024e4e4231561d922ad356a22c0d5d7bc69f
    # wicked is not compatible to procps-ng >= 3.3.17. But from wicked side,
    # this is for reason and may change in the future!
    # Also ensure that we the version of procps-ng is compatible with wicked in SLE!
    my $sysctl_version = script_output(q(/usr/sbin/sysctl --version | grep -oP '[\d\.]+'));
    if (is_sle || check_version('<3.3.17', $sysctl_version)) {
        
        # Load lastgood snapshot, so we do not need to take care of cleanup from previous test!
        autotest::load_snapshot('lastgood');
        $self->rollback_activated_consoles();
        $self->select_serial_terminal();

        $self->get_from_data('wicked/ifcfg/ifcfg-eth0-hotplug-static', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
        $self->wicked_command('ifreload', 'all');

        $self->check_agains_sysctl($ctx);
    }
}



1;
