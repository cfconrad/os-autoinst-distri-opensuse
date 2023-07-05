use Mojo::Base 'basetest';
use testapi;
use lockapi;


sub run {
    my ($self, $args) = @_;

    if (get_var('IS_PARENT')) {
        barrier_create('test1_setup', 2);
        barrier_create('test1_ready', 2);
        barrier_create('test2_setup', 2);
        barrier_create('test2_ready', 2);
        mutex_create('wicked_barriers_created');
    }
    else {
        mutex_wait('wicked_barriers_created');
    }
}

1;
