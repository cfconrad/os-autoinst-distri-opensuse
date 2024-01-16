package wicked::nm_migrate;

use Mojo::Base 'wickedbase';
use utils qw(zypper_call systemctl);

use testapi;

has container_image => "registry.opensuse.org/home/jcronenberg/migrate-wicked/containers/opensuse/migrate-wicked-git:latest";
has container_engine_cmd => undef;

sub migrate
{
    my ($self) = @_;

    record_info("xmlcfg", script_output('wicked show-config'));

    my $args = "";
    $args .= "-e MIGRATE_WICKED_CONTINUE_MIGRATION=true " if get_var("WICKED_NM_MIGRATE_CONTINUE_ON_FAILURE");

    assert_script_run(sprintf('%s run %s -v /etc/sysconfig/network:/etc/sysconfig/network "%s"', $self->container_runtime, $args, $self->container_image));

    record_info("MIGRATED", script_output('for i in /etc/sysconfig/network/NM-migrated/*; do echo "### $i"; cat $i; echo ""; done;'));

    systemctl("enable --force NetworkManager");

    $self->reboot();
}

sub assert_nm_state
{
    my ($self, %args) = @_;

    if ($args{ping_ip}) {
        $self->ping_with_timeout(ip => $args{ping_ip}, interface => $args{iface});
    }

    assert_script_run(sprintf("grep -q '%s' /sys/class/net/%s/operstate", $args{interfaces_down} ? 'down' : 'up', $args{iface}));

}

sub before_test
{
    my $self = shift // wicked::nm_migrate->new();

    $self->prepare_containers();

    assert_script_run(sprintf('%s pull "%s"', $self->container_runtime, $self->container_image));
    zypper_call('-q in NetworkManager');

    # Check  that NetworkManager isn't active
    systemctl('is-active NetworkManager', expect_false => 1);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
