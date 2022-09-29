# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;
use mmapi;

sub sync_next_call()
{
    my $sec = qx(date +%s);
    my $do_sleep = 20 - ($sec % 20);
    record_info('SLEEP', $do_sleep);
    sleep $do_sleep;
}

sub run {
    my ($self, $args) = @_;
    my $name = "THE_BARRIER";

    if (!get_var('PARALLEL_WITH')) {
        # THIS is the parrent JOB
        wait_for_children_to_start();

        barrier_create($name, 2);
        mutex_create('barriers_created');

        sync_next_call();
        barrier_wait($name);
    }
    else {
        # THIS is the child job
        mutex_wait('barriers_created');
        
        sync_next_call();
        sleep 1;
        barrier_wait($name);
    }
}

1;
