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
    $self->select_serial_terminal;


    assert_script_run('echo "HELLO"');
    assert_script_run('echo -n "HELLO"');
    my $out = script_output('echo "HELLO"');
    record_info($out, Dumper($out));
    $out = script_output('echo -n "HELLO"');
    record_info($out, Dumper($out));

    my $rv;

    ($out, $rv) = script_output_with_status('echo ""');
    record_info($out,        Dumper($out));
    record_info("hex($out)", to_hex($out));
    record_info($rv,         Dumper($rv));
    my $nl = $out;

    ($out, $rv) = script_output_with_status('echo "HELLO"');
    record_info($out, Dumper($out));
    record_info($rv,  Dumper($rv));
    die unless $out eq "HELLO$nl";
    ($out, $rv) = script_output_with_status('echo -n "HELLO"');
    record_info($out, Dumper($out));
    record_info($rv,  Dumper($rv));
    die unless $out eq "HELLO";

    ($out, $rv) = script_output_with_status('echo -n ""');
    record_info($out, Dumper($out));
    record_info($rv,  Dumper($rv));
    die unless $out eq "";
}


1;
