# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test Docker’s btrfs storage driver features for image and container management
# Maintainer: qac team <qa-c@suse.de>

package containers::runtime;
use Mojo::Base -base;
use Test::Assert 'assert_equals';

has runtime => undef;

sub assert_script_run {
    my ($self, $cmd, @args) = @_;
    testapi::assert_script_run($self->runtime . " " . $cmd, @args);
}

sub script_run {
    my ($self, $cmd, @args) = @_;
    return testapi::script_run($self->runtime . " " . $cmd, @args);
}

sub script_output {
    my ($self, $cmd, @args) = @_;
    return testapi::script_output($self->runtime . " " . $cmd, @args);
}

sub build {
    my ($self, $dockerfile_path, $container_tag) = @_;
    die 'wrong number of arguments' if @_ < 3;
    testapi::assert_script_run("pushd $dockerfile_path");
    $self->assert_script_run("build -t $container_tag .");
    testapi::assert_script_run('popd');
    testapi::record_info("$container_tag created");
}

sub up {
    my ($self, $tag, %args) = @_;
    die 'tag is required' unless $tag;
    my $mode   = $args{daemon} ? '-d'    : '-it';
    my $remote = $args{cmd}    ? 'sh -c' : '';
    my $ret    = $self->script_run(sprintf q(run --rm '%s' '%s' %s '%s'), $mode, $tag, $remote, $args{cmd});
    testapi::record_info("Remote run on $tag", $args{cmd});
    return $ret;
}

sub pull {
    my ($self, $tag) = @_;
    my $ret = $self->script_run("pull $tag");
    return $ret;
}

sub retrieve_images {
    my ($self) = shift;
    my $images_s = $self->script_output('images -q');
    testapi::record_info("Images", $images_s);
    my @images = split /\s+/, $images_s;
    return \@images;
}

sub retrieve_containers {
    my ($self) = shift;
    my $containers_s = $self->script_output('container ls -q');
    testapi::record_info("Containers", $containers_s);
    my @containers = split /\s+/, $containers_s;
    return \@containers;
}

sub info {
    my ($self, %args) = shift;
    my $property = $args{property} ? qq(--format '{{.$args{property}}}') : '';
    my $expected = $args{value}    ? qq( | grep $args{value})            : '';
    $self->assert_script_run(sprintf('info %s %s', $property, $expected));
}

sub remove_image {
    my ($self, $tag) = @_;
    $self->assert_script_run("rmi -f '$tag'");
}

sub cleanup_system {
    my ($self) = shift;
    # copy from common > clean_container_host
    if (my $output = $self->script_output("ps -q")) {
        for my $id (split(/\s+/, $output)) {
            $self->assert_script_run("stop $id", 180);
        }
    }
    $self->assert_script_run("system prune -a -f", 180);
    assert_equals(0, scalar @{$self->retrieve_containers()}, "containers have not been removed");
    assert_equals(0, scalar @{$self->retrieve_images()},     "images have not been removed");
}

package containers::docker;
use Mojo::Base 'containers::runtime';
has runtime => 'docker';

package containers::podman;
use Mojo::Base 'containers::runtime';
has runtime => 'podman';
1;
