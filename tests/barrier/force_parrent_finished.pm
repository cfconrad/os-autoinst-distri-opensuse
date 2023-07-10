use Mojo::Base 'basetest';
use Time::HiRes qw(time sleep);
use testapi;
use lockapi;

sub dt {
    state $start = time;
    my $title = shift // sprintf('%1.3fs elapsed',(time - $start));
    my $msg =  sprintf("Time: %1.3f\nElapsed: %1.3f\n", time, time - $start);
    record_info($title, $msg);
}

sub barrier_wait_short_timeout {
    my $name = shift;
    my $cnt = 0;
    while (1) {
        my $res = lockapi::_wait_action($name);
        if ($res){
            return 1;
        }
        sleep 0.2;
        record_info("WAIT:" . $cnt++);
    }
}

sub run {
    my ($self, $args) = @_;

    dt();
    if (get_var('IS_PARENT')) {
            dt();
            barrier_wait_short_timeout('test1_setup');
            dt("SYNCED");
            sleep 1;
            dt();
            barrier_wait('test1_ready');
            dt();
    } else {
            dt();
            barrier_wait_short_timeout('test1_setup');
            dt("SYNCED");
            barrier_wait('test1_ready');
            dt();
    }
}

sub test_flags {
    return {fatal => 0};
}
1;
