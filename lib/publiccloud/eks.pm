# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper class for Amazon Elastic Container Registry (ECR)
#
# Maintainer: Ivan Lausuch <ilausuch@suse.de>, qa-c team <qa-c@suse.de>
# Documentation: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html

package publiccloud::eks;
use Mojo::Base 'publiccloud::aws';
use testapi;
use utils;

sub init {
    my ($self) = @_;
    $self->SUPER::init();

    my $repository //= get_var("PUBLIC_CLOUD_CONTAINER_IMAGES_REPO", 'suse-qec-testing');
    $self->{repository} = $repository;

    assert_script_run("aws eks update-kubeconfig --name qe-c-testing");
}

sub create_script_file {
    my ($filename, $fullpath, $content) = @_;
    save_tmp_file($filename, $content);
    assert_script_run(sprintf('curl -o "%s" "%s/files/%s"', $fullpath, autoinst_url, $filename));
    assert_script_run(sprintf('chmod +x %s', $fullpath));
}

sub wait_for_container_log {
    my ($cmd, $container, $text, $timeout) = @_;
    $timeout //= 60;
    while ($timeout > 0) {
        my $output = script_output("$cmd logs $container 2>&1");
        return if ($output =~ /$text/);
        $timeout--;
        sleep 1;
    }
    validate_script_output("$cmd logs $container 2>&1", qr/$text/);
}

=head2 push_container_image
Upload a container image to the ECR. Required parameter is the
name of the image, previously stored in the local registry. And
the tag (name) in the public cloud containers repository
Retrieves the full name of the uploaded image or die.
=cut
sub push_container_image {
    my ($self, $image, $tag) = @_;

    my $region //= $self->region();
    my $aws_account_id   = $self->{aws_account_id};
    my $full_name_prefix = "$aws_account_id.dkr.ecr.$region.amazonaws.com";
    my $full_name        = "$full_name_prefix/$self->{repository}:$tag";
    $self->{tag}         = $tag;

    assert_script_run("aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $full_name_prefix");
    assert_script_run("docker tag $image $full_name");
    assert_script_run("docker push $full_name", 180);
    return $full_name;
}

=head2 push_container_image
Upload a container image to the ECR. Required parameter is the
name of the image, previously stored in the local registry. And
the tag (name) in the public cloud containers repository
Retrieves the full name of the uploaded image or die.
=cut
sub eks_execute_job {
    my ($self, $tag, $command) = @_;
    $self->{tag} = $tag;

    my $job_name = $tag;
    $job_name    =~ s/_/-/;

    my $region //= $self->region();
    my $aws_account_id   = $self->{aws_account_id};
    my $full_name_prefix = "$aws_account_id.dkr.ecr.$region.amazonaws.com";
    my $full_name        = "$full_name_prefix/$self->{repository}:$tag";

    my $job = <<EOT;
apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
spec:
  template:
    spec:
      containers:
      - name: main
        image: $full_name
        command: ["cat",  "/etc/os-release"]
      restartPolicy: Never
  backoffLimit: 4
EOT
    create_script_file("job.yaml", "/tmp/job.yaml", $job);

    assert_script_run('kubectl apply -f /tmp/job.yaml');
    wait_for_container_log("kubectl", "job/$job_name", "SLES");
    assert_script_run("kubectl delete job $job_name");
}

sub clean_job {
  assert_script_run('kubectl delete job $job_name');
}

sub clean_image {
    my $self = shift;
    assert_script_run("aws ecr batch-delete-image --repository-name " . $self->{repository} . " --image-ids imageTag=" . $self->{tag});
    return;
}

1;
