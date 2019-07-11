use Mojo::Base 'opensusebasetest';
use testapi;

sub run {
    my ($self) = @_;
    select_console('root-console');
    assert_script_run('echo "HELLO"');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}


1;
