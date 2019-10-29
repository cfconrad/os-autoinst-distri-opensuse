use Mojo::Base 'opensusebasetest';
use testapi;

sub run {
    sleep 10 if (get_var('DO_NOT_FAIL'));
    record_info('FOO', 'BAR');
}

1;
