# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base module for all DPDK scenarios
# Maintainer: QE Core <qe-core@suse.de>

package Dpdkbase;

use Mojo::Base 'opensusebasetest';
use testapi;
use utils qw(zypper_call);
use serial_terminal 'select_serial_terminal';
use mmapi;
use lockapi;

use constant DPDK_DATA_DIR => '/root/data';

# Interfaces connected to a switch
has pci1 => '0000:00:07.0';
has pci2 => '0000:00:08.0';

# Interfaces connected to delta{123} in a cycle
has pci3 => '0000:00:09.0';
has pci4 => '0000:00:0a.0';

=head2 download_data_dir

Download all files from data/dpdk into DPDK_DATA_DIR.
=cut

sub download_data_dir {
    assert_script_run("mkdir -p '" . DPDK_DATA_DIR . "'");
    # Note: This assumes 'data/dpdk' exists on the host/openqa server
    assert_script_run("(cd '" . DPDK_DATA_DIR . "'; curl -L -v " . autoinst_url . "/data/dpdk > dpdk.data && cpio -id < dpdk.data && mv data dpdk && rm dpdk.data)");
}


=head2 get_from_data

  get_from_data($source, $target [, executable => 0])

Copies a file from the local DPDK data directory to the specified target.
=cut

sub get_from_data {
    my ($self, $source, $target, %args) = @_;

    $source .= check_var('IS_WICKED_REF', '1') ? 'ref' : 'sut' if $args{add_suffix};
    assert_script_run("cp -r '" . DPDK_DATA_DIR . '/' . $source . "' '$target'");
    assert_script_run("chmod +x '$target'") if $args{executable};
}

sub get_ifc_by_pci_id {
    my ($self, $pci_id) = @_;

    my $id = script_output("ls -1 '/sys/bus/pci/devices/$pci_id/net' 2> /dev/null");

    return $id;
}

sub install_dependencies {
    my ($self) = @_;
    my @packages = qw(dpdk dpdk-tools pciutils);
    my @to_install;
    for my $pkg (@packages) {
        if (script_run("rpm -q $pkg") != 0) {
            push @to_install, $pkg;
        }
    }

    if (@to_install) {
        record_info('install', 'Installing packages: ' . join(' ', @to_install));
        zypper_call('in ' . join(' ', @to_install));
    }
}

sub record_console_test_result {
    my ($self, $title, $content, %args) = @_;
    $args{result} //= 'fail';
    $title =~ s/:/_/g;
    my $details = $self->record_testresult($args{result});
    my $filename = $self->next_resultname('txt');
    $details->{_source} = 'parser';
    $details->{text} = $filename;
    $details->{title} = $title;
    $self->write_resultfile($filename, $content);
}

sub run_test_shell_script
{
    my ($self, $title, $script_cmd, %args) = @_;
    $args{timeout} //= 300;

    my $output = script_output($script_cmd . '; echo "==COLLECT_EXIT_CODE==$?=="', proceed_on_failure => 1, timeout => $args{timeout});
    my $result = $output =~ m/==COLLECT_EXIT_CODE==0==/ ? 'ok' : 'fail';
    $self->record_console_test_result($title, $script_cmd . "\n\n" . $output, result => $result);
}

sub num_children {
    my ($self) = @_;

    unless ($self->{_num_children}) {
        my $children = get_children();
        $self->{_num_children} = scalar(keys(%$children));
    }
    return $self->{_num_children};
}

sub do_barrier_wait {
    my ($self, $name) = @_;
    barrier_wait({name => $name, check_dead_job => 1});

    # This is to mitigate the problem, that if a parallel job is running in the
    # barrier_wait() poll loop, while this job finished. This would lead to a
    # failure on the other side.
    $self->{last_barrier_wait_call} = time;
}


sub post_run {
    my ($self) = @_;

    if ($self->num_children() > 0) {
        my $time_since_barrier_wait = time - ($self->{last_barrier_wait_call} // 0);
        if ($time_since_barrier_wait < lockapi::POLL_INTERVAL) {
            my $seconds = lockapi::POLL_INTERVAL - $time_since_barrier_wait;
            #see https://github.com/os-autoinst/os-autoinst/issues/2340
            bmwqemu::diag("If the parallel job might wait in barrier_wait() poll loop," .
                  " we should not finish this parent job to early! sleep $seconds seconds");
            sleep $seconds;
        }
    }
}

1;
