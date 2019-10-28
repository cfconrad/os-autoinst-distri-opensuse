use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use Data::Dumper;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;


    my $out = script_output('echo "HELLO"');
    record_info($out, Dumper($out));
}


1;
