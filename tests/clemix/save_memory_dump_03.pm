use Mojo::Base 'opensusebasetest';
use testapi;

sub run {
    my ($self) = @_;
    die "fail here, try to reproduce bug";
}

sub post_fail_hook {
    print("CFC-DEBUG: in post_fail_hook()$/");
    save_memory_dump;
}



1;
