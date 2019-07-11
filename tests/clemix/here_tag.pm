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
use serial_terminal;


sub build_script
{
    my ($script, %args) = @_;
    my $marker      = "OFASFDAOJHS";
    my $script_path = "/tmp/foo.sh";
    my $heretag     = 'EOT_' . $marker;
    my $cat         = "cat > $script_path << '$heretag'; echo $marker-\$?-";

    testapi::wait_serial(serial_term_prompt(), no_regex => 1, quiet => $args{quiet}) || die("serial prompt");
    bmwqemu::log_call("Content of $script_path :\n \"$cat\" \n");
    testapi::type_string($cat . "\n");
    testapi::wait_serial("$cat", no_regex => 1, quiet => $args{quiet}) || die("wait $cat");
    testapi::type_string("$script\n$heretag\n");
    testapi::wait_serial("> $heretag", no_regex => 1, quiet => $args{quiet}) || die("wait > $heretag");
    testapi::wait_serial("$marker-0-", quiet => $args{quiet}) || die("wait script finish");
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    for (my $i = 0; $i < 1000; $i++) {
        build_script("echo 'fofoasfofoasdfooafoasdfoosadf' | grep foo | sort | uniq");
    }

}


1;
