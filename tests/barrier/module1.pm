use Mojo::Base 'basetest';
use testapi;
use lockapi;


sub run {
    my ($self, $args) = @_;

    if (get_var('IS_PARENT')) {
            barrier_wait('test1_setup');
            barrier_wait({name => 'test1_ready', timeout => 60});
    } else {
            barrier_wait('test1_setup');
            die("Module FAILED!");
    }
}

sub test_flags {
    return {fatal => 0};
}
1;
