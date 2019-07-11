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

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    setup_static_network(ip => '10.0.2.15/24');

    systemctl('is-active network');
    systemctl('is-active wicked');

    zypper_call(' -q in git-core make gcc ');

    assert_script_run('git clone https://github.com/IAIK/ZombieLoad.git');

    assert_script_run('make -C ZombieLoad/attacker/variant1_linux');
    assert_script_run('make -C ZombieLoad/victim/userspace_linux_windows');

    change_grub_config('"$', ' nopti nokaslr"', 'GRUB_CMDLINE_LINUX_DEFAULT=', '', 1);
    power_action('reboot');
    $self->wait_boot;

    $self->select_serial_terminal;
    assert_script_run('lscpu -e');
    assert_script_run('taskset -c 0 ZombieLoad/victim/userspace_linux_windows/secret C & sleep 10');
    assert_script_run('taskset -c 1 ZombieLoad/attacker/variant1_linux/leak');

    sleep;

}


1;
