# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: sysctl --system and wicked should have the same order in reading
#          sysctl configuration files. This test use debug output of wicked and
#          sysctl and check the order load of sysctl-configuration files
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wickedbase';
use testapi;
use Mojo::File qw(path);

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

    my $f = path('ulogs/teststeps.txt');
    $f->spurt($f->slurp . sprintf("\ncheck => [qw(%s)]\n},", join(" ", @wicked)));
}

sub check_agains_sysctl {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal();
    mkdir 'ulogs';
    path('ulogs/teststeps.txt')->spurt("");

    return if $self->skip_by_wicked_version('>=0.6.68');

    $self->get_from_data('wicked/ifcfg/ifcfg-eth0-hotplug-static', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->wicked_command('ifreload', 'all');

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

sub _assert_script_run {
    my ($cmd, @args) = @_;

    my $f = path('ulogs/teststeps.txt');
    $f->spurt($f->slurp . "\n{\ncmd => '$cmd',");

    assert_script_run($cmd, @args);
}

sub check_static {
    my ($self, $ctx) = @_;

    mkdir 'ulogs';
    path('ulogs/teststeps.txt')->spurt("");


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
        _assert_script_run("mkdir -p $dir && touch $dir/20-test.conf");
        check_load_order();
    }
    for my $dir (reverse @sysctl_d) {
        _assert_script_run("mkdir -p $dir && touch $dir/21-test.conf");
        check_load_order();
    }

    for my $dir (@sysctl_d) {
        _assert_script_run("rm $dir/20-test.conf");
        check_load_order();
    }

    for my $dir (reverse @sysctl_d) {
        _assert_script_run("rm $dir/21-test.conf");
        check_load_order();
    }

    # Check SUSE special ifsysctl files
    my @sysctl_order = sysctl_get_file_order;
    my $sysctl_f1 = '/etc/sysconfig/network/ifsysctl';
    my $sysctl_f2 = '/etc/sysconfig/network/ifsysctl-' . $ctx->iface();
    _assert_script_run("touch $sysctl_f1");
    check_load_order([@sysctl_order, $sysctl_f1]);

    _assert_script_run("touch $sysctl_f2");
    check_load_order([@sysctl_order, $sysctl_f1, $sysctl_f2]);

    _assert_script_run("rm $sysctl_f1");
    check_load_order([@sysctl_order, $sysctl_f2]);

    _assert_script_run("rm $sysctl_f2");
    check_load_order();

    # Check broken symlinks
    for my $dir (reverse @sysctl_d) {
        my $file = "$dir/20-test.conf";
        _assert_script_run("mkdir -p $dir && ln -s /I_do_not_exists $file");
        check_load_order();
        die("Missing broken '$file' in logs") unless grep { $_ eq $file } wicked_get_file_order();
        die("Missing error message for '$file'") unless grep { $_ eq $file } wicked_get_file_errors();
    }

    # Exceptional behavior for /etc/sysctl.conf, it is silently ignored
    my $file = "/etc/sysctl.conf";
    _assert_script_run("rm $file");
    _assert_script_run("ln -s /I_do_not_exists $file");
    check_load_order();
    die("Wrongly showing broken '$file' in logs") if grep { $_ eq $file } wicked_get_file_order();
    die("Wrongly showing missing '$file' in logs") if grep { $_ eq $file } wicked_get_file_errors();

}

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal();

    return if $self->skip_by_wicked_version('>=0.6.68');

    $self->get_from_data('wicked/ifcfg/ifcfg-eth0-hotplug-static', '/etc/sysconfig/network/ifcfg-' . $ctx->iface());
    $self->wicked_command('ifreload', 'all');
    $self->check_static($ctx);

}



1;
