use Mojo::Base 'opensusebasetest';
use testapi;
use bootloader_setup qw(change_grub_config grub_mkconfig);
use commands;
use File::Basename;
use Mojo::Util qw'b64_encode b64_decode sha1_sum trim';
#use Mojo::File qw'tempfile';
use File::Temp 'tempfile';
use network_utils 'setup_static_network';
use power_action_utils 'power_action';
use utils;
require bmwqemu;
use Data::Dumper;
use Mojo::Util qw(b64_encode b64_decode sha1_sum trim);
use Mojo::File 'path';

sub to_hex
{
    my $string = shift;
    my $out    = "";
    for my $s (split(//, $string)) {
        $out .= sprintf(" %02x", ord($s));
    }
    return $out;
}

sub run {
    my ($self) = @_;
    my $console = $self->select_serial_terminal;
    #select_console('root-console');
    my $original = 'data/clemix/big_file';

    #   assert_script_run('wget http://cfconrad-vm.qa.suse.de/tests/5315/file/cgroup_fj_stress_net_cls_2_2_none-output_ltp_cgroup_fj_stress.sh -O big_file');

    assert_script_run 'curl -O ' . data_url("clemix/big_file");
    system('mkdir -p ulogs/') == 0 or die('Failed to create ulogs/ directory');
    my $output = path($bmwqemu::vars{CASEDIR} . '/' . $original)->slurp();
    $output = trim($output);
    #my $output  = script_output('cat big_file', quiet => 1, timeout => 10);
    my $sha1sum = sha1_sum($output);
    path('ulogs/original')->spurt($output);
    record_info("FILE", $sha1sum . "\n\n" . $output);
    for my $i ((1 .. 1000)) {
        $output = undef;
        assert_script_run("echo 'RUN: $i'" . $i, quiet => 1);
        eval {
            $output = script_output('cat big_file', quiet => 1, timeout => 10, proceed_on_failure => 1);
        };
        my $sha1sum_2 = '';
        $sha1sum_2 = sha1_sum($output) if (defined($output));
        if ($sha1sum eq $sha1sum_2) {
            record_info("OK $i");
        } else {
            script_run("cat /sys/kernel/debug/virtio-ports/*");
            record_info("FAILED $i", $sha1sum . "\n" . $sha1sum_2, result => 'fail');
            path('ulogs/failed')->spurt($output);
            die("first sha1sum was wrong");
        }
    }
}


1;
