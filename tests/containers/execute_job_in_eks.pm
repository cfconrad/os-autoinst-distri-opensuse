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
use publiccloud::k8s_utils;
use mmapi 'get_current_job_id';

sub run {
    my ($self, $args) = @_;

    $self->select_serial_terminal;
    install_kubectl();

    my $provider      = $self->provider_factory();
    my $tag           = join('-', get_var('PUBLIC_CLOUD_RESOURCE_NAME'), get_current_job_id());
    my $job_name      = $tag =~ s/_/-/r;
    my $env           = $provider->get_kubectl_env();
    my $image         = $provider->get_container_image_name($tag);
    $self->{provider} = $provider;
    $self->{job_name} = $job_name;
    $provider->{tag}  = $tag;
    my $job           = <<EOT;
apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
spec:
  template:
    spec:
      containers:
      - name: main
        image: $image
        command: [ "cat", "/etc/os-release" ]
      restartPolicy: Never
  backoffLimit: 4
EOT
 
    $provider->eks_apply_manifest($job);

    wait_for_container_log("$env kubectl ", "job/$job_name", "SLES");
    assert_script_run("$env kubectl delete job $job_name");
}

sub post_fail_hook {
    my ($self) = @_;
    my $env = $self->{provider}->get_kubectl_env();
    script_output("$env kubectl delete job ". $self->{job_name});
    $self->{provider}->clean_image();
}

sub post_run_hook {
    my ($self) = @_;
    $self->{provider}->clean_image();
}

1;
