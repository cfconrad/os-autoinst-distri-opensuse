use Mojo::Base 'basetest';
use testapi;
use lockapi;

sub dt {
    state $start = time;
    record_info((time - $start) . " elapsed");
}

sub run {
    my ($self, $args) = @_;

    dt();
    if (get_var('IS_PARENT')) {
            dt();
            barrier_wait('test1_setup');
            dt();
            sleep 1;
            dt();
            barrier_wait('test1_ready');
            dt();
    } else {
            dt();
            barrier_wait('test1_setup');
            dt();
            barrier_wait('test1_ready');
            dt();
    }
}

sub test_flags {
    return {fatal => 0};
}
1;
