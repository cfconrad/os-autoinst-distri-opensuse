use Mojo::Base -strict;
use Test::More;
use Test::Exception;
use Test::Warnings;

use utils;
use testapi;
use autotest;
use basetest;

use Test::MockModule;

subtest 'validate_script_output_retry' => sub {
    my $module = Test::MockModule->new('testapi');

    my $basetest = Test::MockModule->new('basetest');
    $basetest->noop('record_resultfile');
    $autotest::current_test = new basetest;

    $module->mock('script_output', sub { 'foo' });
    lives_ok { validate_script_output_retry('echo foo', qr/foo/, retry => 2) } 'Do not throw exception';
    throws_ok { validate_script_output_retry('echo foo', qr/bar/, retry => 2, delay=> 0) }  qr/validate output/,  'Exception thrown';

    my @results;
    $module->mock('script_output', sub { shift @results });

    @results = qw(1 2 3 foo);
    lives_ok { validate_script_output_retry('echo foo', qr/foo/, retry => 4, delay=> 0) } 'Success on 4th retry';
    @results = qw(1 2 3 foo);
    throws_ok { validate_script_output_retry('echo foo', qr/foo/, retry => 3, delay=> 0) }  qr/validate output/,  'Not enough retries';
};

done_testing;
