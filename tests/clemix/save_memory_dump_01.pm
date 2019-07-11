use Mojo::Base 'opensusebasetest';
use testapi;

sub run {
    die("here");
}

sub post_fail_hook {
    print("CFC-DEBUG: in post_fail_hook()$/");
    save_memory_dump;
}

1;
