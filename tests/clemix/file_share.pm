use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal qw(download_file upload_file add_serial_console);

sub stopwatch_start
{
    return time();
}

sub stopwatch_end
{
    my ($watch, $msg) = @_;
    $msg //= '';
    my $duration = time() - $watch;
    record_info('STOP WATCH', sprintf($msg . "\ntook %d seconds", $duration));
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    add_serial_console('hvc1');

    select_console('root-virtio-terminal1');
    download_file('data/publiccloud/ec2utils.conf', '/tmp/ec2utils.conf');
    my $w = stopwatch_start();
    download_file('data/10M', '/tmp/10M');
    stopwatch_end($w, "Download 10M file");

    $self->select_serial_terminal;
    for (my $i = 0; $i < 3; $i++) {
        script_run('echo -e "[' . sprintf("%04d", $i) . ']fooofofofofofofasdf\n   `date`" >> foo', quiet => 1);
    }

    select_console('root-virtio-terminal1');
    upload_file('foo',                'blub.txt');
    upload_file('/tmp/ec2utils.conf', 'ec2utils.conf');
    $w = stopwatch_start();
    upload_file('/tmp/10M', '10M');
    stopwatch_end($w, "Upload 10M file");

    # make small upload and download via serial
    download_file('data/wicked/ifbind.sh', '/tmp/ifbind.sh');
    upload_file('/tmp/ifbind.sh', 'ifbind.sh');
}


1;
