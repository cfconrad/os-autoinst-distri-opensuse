use Mojo::Base 'consoletest';
use testapi;
use Time::HiRes qw(time);

sub run {
    my $self = shift;

    my $t_start      = time();
    my $avg_duration = 0;

    $self->select_serial_terminal;

    for my $i (1 .. get_var('MAX_LOOPS', 10)) {
        print("X" x 30 . $/);
        print($i . $/);
        my $t_start_script_output  = time();
        my $output                 = script_output('w', type_command => 1);
        my $t                      = time();
        my $duration_script_output = $t - $t_start_script_output;
        $avg_duration = ($avg_duration * ($i-1) + ($t-$t_start_script_output)) / $i;
        record_info('Measure', 'Loop: ' . $i . $/ . 'Allover: ' . ($t-$t_start) . $/ . "Avg: " . $avg_duration . $/ . "Current:" . $duration_script_output . $/);
        print $output . $/;
        if ($output !~ /load average/m) {
            sleep 5;
            assert_script_run('cat /tmp/scriptrTijn.sh');
            assert_script_run('cat /tmp/scriptrTijn.sh | od');
            assert_script_run('cat /tmp/scriptrTijn.sh | od -c');
            die("Missing output");
        }
        print("X" x 30 . $/);
    }
}

1;
