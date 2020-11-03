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
use testapi;
use Test::Assert 'assert_equals';

has runtime => undef;

sub _assert_script_run {
    my ($self, $cmd, @args) = @_;
    assert_script_run($self->runtime . " " . $cmd, @args);
}

sub _script_run {
    my ($self, $cmd, @args) = @_;
    return script_run($self->runtime . " " . $cmd, @args);
}

sub _script_output {
    my ($self, $cmd, @args) = @_;
    return script_output($self->runtime . " " . $cmd, @args);
}

sub build {
    my ($self, $dockerfile_path, $container_tag) = @_;
    die 'wrong number of arguments' if @_ < 3;
    assert_script_run "cd $dockerfile_path";
    assert_script_run "$self->{runtime} build -t $container_tag .";
    record_info "$container_tag created";
}

sub up {
    my ($self, $tag, %args) = @_;
    die 'tag is required' unless $tag;
    my $mode   = $args{daemon} ? '-d'    : '-it';
    my $remote = $args{cmd}    ? 'sh -c' : '';
    my $ret    = script_run sprintf qq($self->{runtime} run --rm %s %s %s '%s'), $mode, $tag, $remote, $args{cmd};
    record_info "Remote run on $tag", $args{cmd};
    return $ret;
}

sub pull {
    my ($self, $tag) = @_;
    my $ret = script_run "$self->{runtime} pull $tag";
    return $ret;
}

sub retrieve_images {
    my ($self) = shift;
    my $images_s = script_output qq/docker images -q/;
    record_info "Images", $images_s;
    my @images = split /[\n\t]/, $images_s;
    return \@images;
}

sub retrieve_containers {
    my ($self) = shift;
    my $containers_s = script_output qq/docker container ls -q/;
    record_info "Containers", $containers_s;
    my @containers = split /[\n\t]/, $containers_s;
    return \@containers;
}

sub info {
    my ($self, %args) = shift;
    my $property = $args{property} ? qq(--format '{{.$args{property}}}') : '';
    my $expected = $args{value}    ? qq( | grep $args{value})            : '';
    assert_script_run sprintf qq($self->{runtime} info %s %s), $property, $expected;
}

sub remove_image {
    my ($self, $tag) = @_;
    assert_script_run qq($self->{runtime} rmi -f $tag);
}

sub cleanup_system {
    my ($self) = shift;
    # copy from common > clean_container_host
    assert_script_run("$self->{runtime} stop \$($self->{runtime} ps -q)", 180) if script_output("$self->{runtime} ps -q | wc -l") != '0';
    assert_script_run("$self->{runtime} system prune -a -f",              180);
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
