# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Push a container image to the public cloud container registry
#
# Maintainer: Ivan Lausuch <ilausuch@suse.com>, qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';

sub run {
    my ($self, $args) = @_;

    $self->select_serial_terminal;

    my $provider      = $self->provider_factory();
    $self->{provider} = $provider;
    my $tag           = join('-', get_var('PUBLIC_CLOUD_RESOURCE_NAME'), get_current_job_id());
    my $command       = [ "cat", "/etc/os-release" ];
    my $eks_key       = get_required_var('PUBLIC_CLOUD_EKS_KEY');
    my $eks_secret    = get_required_var('PUBLIC_CLOUD_EKS_SECRET');

    script_output('curl -LO https://dl.k8s.io/release/v1.22.2/bin/linux/amd64/kubectl');
    script_output('chmod a+x kubectl');
    script_output('rm /usr/bin/kubectl');
    script_output('mv kubectl /usr/bin/kubectl');
    
    assert_script_run('export AWS_ACCESS_KEY_ID2=$AWS_ACCESS_KEY_ID');
    assert_script_run('export AWS_SECRET_ACCESS_KEY2=$AWS_SECRET_ACCESS_KEY');
    assert_script_run('export AWS_ACCESS_KEY_ID="' . $eks_key . '"');
    assert_script_run('export AWS_SECRET_ACCESS_KEY="' . $eks_secret . '"');
    
    $provider->eks_execute_job($tag, $command);
}

sub restore_aws_access {
    assert_script_run('export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID2');
    assert_script_run('export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY2');
}

sub post_fail_hook {
    my ($self) = @_;
    restore_aws_access();
    $self->{provider}->clean_image();
}

sub post_run_hook {
    my ($self) = @_;
    restore_aws_access();
    $self->{provider}->clean_image();
}

1;
