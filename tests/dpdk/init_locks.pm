use Mojo::Base 'Dpdkbase';
use testapi;
use lockapi;
use mmapi;
use Data::Dumper;

sub run {
    my ($self, $args) = @_;

    my $children = get_children();
    record_info('children', Dumper($children));

    if ($self->num_children() > 0) {
        barrier_create("wait_1", $self->num_children() + 1);
        barrier_create("wait_2", $self->num_children() + 1);
        barrier_create("wait_3", $self->num_children() + 1);
        barrier_create("wait_4", $self->num_children() + 1);

        mutex_create('dpdk_barriers_created');
    } else {
        mutex_wait('dpdk_barriers_created');
    }
}

1;
