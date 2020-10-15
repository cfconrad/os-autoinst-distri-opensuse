use base 'wickedbase';
use strict;
use warnings;
use testapi;
use utils qw(zypper_call systemctl file_content_replace zypper_ar);
use version_utils 'is_sle';
use network_utils qw(iface setup_static_network);
use serial_terminal;
use main_common 'is_updates_tests';
use repo_tools 'generate_version';
use power_action_utils 'power_action';

sub run {
    my ($self, $ctx) = @_;
    $self->select_serial_terminal;

    if (check_var('WICKED', 'ipv6')) {
        setup_static_network(ip => $self->get_ip(type => 'host', netmask => 1), silent => 1, ipv6 =>
              $self->get_ip(type => 'dhcp6', netmask => 1));
    } else {
        setup_static_network(ip => $self->get_ip(type => 'host', netmask => 1), silent => 1);
    }


    assert_script_run('zypper ar --no-gpgcheck --refresh  -n "custom_kernel_repo" http://download.suse.de/ibs/home:/tsbogend:/bsc1177678/standard/home:tsbogend:bsc1177678.repo ');
    assert_script_run('zypper in -y --from custom_kernel_repo --force kernel-default');
    assert_script_run('zypper rm -y kernel-default-5.3.18-33.2.x86_64');

    assert_script_run '[ "$(zypper se -s kernel-default | grep -c i+)" = "1" ]', fail_message => 'More than one kernel was installed';

    power_action('reboot');
}

1;
