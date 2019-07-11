use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal;
use Mojo::File 'path';

sub run {
    my ($self) = @_;
    my $console = $self->select_serial_terminal;

    assert_script_run('zypper -n --gpg-auto-import-keys ar -f  --no-gpgcheck  http://dist.suse.de/ibs/QA:/Head/SLE-12-SP5 qa-head');
    assert_script_run('zypper -n --gpg-auto-import-keys ref --repo qa-head');
    assert_script_run('zypper -n in --recommends ltp');
    assert_script_run('export LTPROOT=/opt/ltp');
    assert_script_run('export PATH=$LTPROOT/testcases/bin:$PATH');
    assert_script_run('cd /opt/ltp/testcases/bin');

    upload_logs('$LTPROOT/runtest/controllers', log_name => 'upload');
    my $runfile = path('ulogs/upload-controllers')->slurp;
    my $timeout = 900;


    for my $line (split(/\r?\n/, $runfile)) {
        next if ($line =~ /^\s*#/);
        my ($name, $cmd) = split(/\s+/, $line, 2);
        next if ($name !~ /^cgroup_fj/);
        record_info($name, "");
        assert_script_run("echo '$name'");
        #        script_output($cmd, timeout => 900);

        my $fin_msg  = "### TEST $name COMPLETE >>> ";
        my $cmd_text = qq($cmd; echo "$fin_msg\$?");

        wait_serial(serial_term_prompt(), undef, 0, no_regex => 1);
        type_string($cmd_text);
        wait_serial($cmd_text, undef, 0, no_regex => 1);
        type_string("\n");

        my $test_log = wait_serial(qr/$fin_msg\d+/, $timeout, 0, record_output => 1);
        if (!defined($test_log)) {
            die("Timeout on wait_werial($fin_msg)");
        }
        if ($test_log =~ /$fin_msg(\d+)/) {
            if ($1 != 0 && $1 != 32) {
                die("$name failed");
            }
        } else {
            die("Unable to get exitcode");
        }
    }
}

sub post_fail_hook
{
    assert_script_run("echo 'ENTERED POST FAILURE HOOK'");
    sleep;
}

1;
