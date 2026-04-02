# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test ovn controller.
# * Each host install dpdk/openvswitch/ovn
# * Only Host1 is running the ovn-northbridge and ovn-southbridge
# * Each host run a ovn-controller connected to host1
#
# Maintainer: QE Core <qe-core@suse.de>
use Mojo::Base 'Dpdkbase', -signatures;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call);
use Mojo::JSON qw(decode_json);
use Data::Dumper;
use lockapi;

sub extract_var($file, $var) {
    my $line = script_output(qq%(source $file && echo "$var=\$$var")%);

    if (length($line) > length($var) + 1) {
        return substr($line, length($var) + 1);
    }
    return undef;
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    Dpdkbase::download_data_dir();
    my $script_dir = Dpdkbase::DPDK_DATA_DIR . '/dpdk/ovn_controller';

    barrier_wait({name => 'wait_1', check_dead_job => 1});

    if (get_var('DPDK_HOST') eq 1) {
        my $env = 'LOCAL_HOSTNAME=host1';
        $env .= ' CTRL_IFC=' . $self->get_ifc_by_pci_id($self->pci1);
        $env .= ' HOST1_DATA_PCI_ID=' . $self->pci2;
        $self->run_test_shell_script('host1.sh', "$env $script_dir/host1.sh");
    }

    barrier_wait({name => 'wait_2', check_dead_job => 1});

    if (get_var('DPDK_HOST') eq 2) {
        my $env = 'LOCAL_HOSTNAME=host2';
        $env .= ' CTRL_IFC=' . $self->get_ifc_by_pci_id($self->pci1);
        $env .= ' HOST2_DATA_PCI_ID=' . $self->pci2;
        $self->run_test_shell_script('host2.sh', "$env $script_dir/host2.sh");
        assert_script_run('ip netns exec ns2 ip a s');
        assert_script_run('ip netns exec ns2 ip r s');
        assert_script_run('ip netns exec ns2 iperf3 -D -s');
    }
    if (get_var('DPDK_HOST') eq 3) {
        my $env = 'LOCAL_HOSTNAME=host3';
        $env .= ' CTRL_IFC=' . $self->get_ifc_by_pci_id($self->pci1);
        $env .= ' HOST3_DATA_PCI_ID=' . $self->pci2;
        $self->run_test_shell_script('host3.sh', "$env $script_dir/host3.sh");
        assert_script_run('ip netns exec ns3 ip a s');
        assert_script_run('ip netns exec ns3 ip r s');
        assert_script_run('ip netns exec ns3 iperf3 -D -s');
    }

    barrier_wait({name => 'wait_3', check_dead_job => 1});

    if (get_var('DPDK_HOST') eq 1) {
        assert_script_run('ip netns exec ns1 ip a s');
        assert_script_run('ip netns exec ns1 ip r s');
        for my $host (qw(HOST2 HOST3)) {
            my $ip = extract_var("$script_dir/setup.cfg", "${host}_TEST_IP");

            assert_script_run("ip netns exec ns1 ping -c 5 $ip");
            assert_script_run("ip netns exec ns1 iperf3 -c $ip -J | tee $host.json");

            my $json = decode_json(script_output("cat $host.json"));

            my $sender_bps = $json->{end}{sum_sent}{bits_per_second};
            my $receiver_bps = $json->{end}{sum_received}{bits_per_second};

            my $sender_mbps = $sender_bps / 1_000_000;
            my $receiver_mbps = $receiver_bps / 1_000_000;

            my $msg = '';
            $msg .= sprintf "Sender Throughput:   %.2f Mbps\n", $sender_mbps;
            $msg .= sprintf "Receiver Throughput: %.2f Mbps\n", $receiver_mbps;

            record_info('RESULT', $msg);
        }
    }
    barrier_wait({name => 'wait_4', check_dead_job => 1});
}

1;
