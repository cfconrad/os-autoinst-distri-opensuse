# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: module loader of container tests
# Maintainer: qa-c@suse.de

package main_containers;
use base 'Exporter';
use Exporter;
use utils;
use version_utils;
use testapi qw(check_var get_required_var get_var);
use Utils::Architectures;
use strict;
use warnings;
use Carp 'croak';


our @EXPORT = qw(
  is_container_test
  load_container_tests
);

sub container_loadtest {
    my ($test, %args) = @_;
    croak "extensions are not allowed here '$test'" if $test =~ /\.pm$/;
    autotest::loadtest("tests/$test.pm", %args);
}

sub is_container_test {
    return get_var('CONTAINER_RUNTIME', 0);
}

sub is_container_image_test {
    return get_var('CONTAINERS_UNTESTED_IMAGES', 0);
}

sub is_res_host {
    # returns if booted image is RedHat Expanded Support
    return get_var("HDD_1") =~ /(res82.qcow2|res79.qcow2)/;
}

sub is_ubuntu_host {
    # returns if booted image is Ubuntu
    return get_var("HDD_1") =~ /ubuntu/;
}

sub load_image_tests_podman {
    container_loadtest 'containers/podman_image';
}

sub load_image_tests_docker {
    container_loadtest 'containers/docker_image';
    # container_diff package is not avaiable for <=15 in aarch64
    # Also, we don't want to run it on 3rd party hosts
    unless ((is_sle("<=15") and is_aarch64) || get_var('CONTAINERS_NO_SUSE_OS')) {
        container_loadtest 'containers/container_diff';
    }
}

sub load_host_tests_podman {
    if (is_leap('15.1+') || is_tumbleweed || is_sle("15-sp1+")) {
        # podman package is only available as of 15-SP1
        container_loadtest 'containers/podman';
        container_loadtest 'containers/podman_image' unless is_public_cloud();
        container_loadtest 'containers/podman_3rd_party_images';
        container_loadtest 'containers/buildah';
        container_loadtest 'containers/rootless_podman';
    }
}

sub load_host_tests_docker {
    container_loadtest 'containers/docker';
    container_loadtest 'containers/docker_image' unless (is_public_cloud());
    container_loadtest 'containers/docker_3rd_party_images';
    if (is_opensuse() || (is_sle(">15") && !is_aarch64())) {
        # these 2 packages are not avaiable for <=15 (aarch64 only)
        # zypper-docker is not available in factory
        container_loadtest 'containers/zypper_docker' unless is_tumbleweed;
        container_loadtest 'containers/docker_runc';
    }
    unless (check_var('BETA', 1)) {
        # These tests use packages from Package Hub, so they are applicable
        # to maintenance jobs or new products after Beta release
        container_loadtest 'containers/registry' if is_x86_64;
        container_loadtest 'containers/docker_compose';
    }
    container_loadtest 'containers/validate_btrfs' if is_x86_64;
    container_loadtest "containers/container_diff" if (is_opensuse());
}


sub load_container_tests {
    my $runtime = get_required_var('CONTAINER_RUNTIME');
    if (get_var('BOOT_HDD_IMAGE')) {
        container_loadtest 'installation/bootloader_zkvm' if is_s390x;
        container_loadtest 'boot/boot_to_desktop';
    }

    if (is_container_image_test()) {
        # Container Image tests
        container_loadtest 'containers/host_configuration' unless (is_res_host || is_ubuntu_host);
        load_image_tests_podman() if ($runtime =~ 'podman');
        load_image_tests_docker() if ($runtime =~ 'docker');
    } else {
        # Container Host tests
        load_host_tests_podman() if ($runtime =~ 'podman');
        load_host_tests_docker() if ($runtime =~ 'docker');
    }
    container_loadtest 'console/coredump_collect';
}

1;
