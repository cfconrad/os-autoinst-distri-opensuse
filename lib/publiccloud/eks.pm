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
use publiccloud::k8s_utils;

sub init {
    my ($self) = @_;
    $self->SUPER::init();

    my $repository //= get_var("PUBLIC_CLOUD_CONTAINER_IMAGES_REPO", 'suse-qec-testing');
    $self->{repository} = $repository;

    assert_script_run("aws eks update-kubeconfig --name qe-c-testing");
}

=head2 push_container_image
Upload a container image to the ECR. Required parameter is the
name of the image, previously stored in the local registry. And
the tag (name) in the public cloud containers repository
Retrieves the full name of the uploaded image or die.
=cut
sub push_container_image {
    my ($self, $image, $tag) = @_;
    $self->{tag} = $tag;

    my $region //= $self->region();
    my $aws_account_id   = $self->{aws_account_id};
    my $full_name_prefix = "$aws_account_id.dkr.ecr.$region.amazonaws.com";
    my $full_name        = "$full_name_prefix/$self->{repository}:$tag";

    assert_script_run("aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $full_name_prefix");
    assert_script_run("docker tag $image $full_name");
    assert_script_run("docker push $full_name", 180);
    return $full_name;
}

=head2 eks_apply_manifest
Apply a kubernetes manifest 
=cut
sub eks_apply_manifest {
    my ($self, $manifest) = @_;

    my $env      = get_kubectl_env();
    my $filename = create_manifest($manifest);

    assert_script_run("$env kubectl apply -f $filename");
}

=head2 get_kubectl_env
Get the environment variables needed to call kubectl
=cut
sub get_kubectl_env {
    my $eks_key    = get_required_var('PUBLIC_CLOUD_EKS_KEY');
    my $eks_secret = get_required_var('PUBLIC_CLOUD_EKS_SECRET');
    'AWS_ACCESS_KEY_ID="' . $eks_key . '" AWS_SECRET_ACCESS_KEY="' . $eks_secret . '"';
}

=head2 get_container_image_name
Get the full name for a container image
=cut
sub get_container_image_name {
    my ($self, $tag) = @_;
    my $region //= $self->region();
    my $aws_account_id   = $self->{aws_account_id};
    my $full_name_prefix = "$aws_account_id.dkr.ecr.$region.amazonaws.com";
    "$full_name_prefix/$self->{repository}:$tag";
}

=head2 clean_image
Delete a ECR image
=cut
sub clean_image {
    my $self = shift;
    assert_script_run("aws ecr batch-delete-image --repository-name " . $self->{repository} . " --image-ids imageTag=" . $self->{tag});
    return;
}

1;
