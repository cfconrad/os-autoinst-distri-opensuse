use Mojo::Base 'basetest';
use testapi;
use lockapi;


sub run {
    my ($self, $args) = @_;

    if (get_var('IS_PARENT')) {
            barrier_wait('test2_setup');
            barrier_wait('test2_ready');
    } else {
            barrier_wait('test2_setup');
            barrier_wait('test2_ready');
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
