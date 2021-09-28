# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base class for publiccloud kubernetes tests
#
# Maintainer: Ivan Lausuch Sales <ilausuch@suse.com>, qa-c team <qa-c@suse.de>

package publiccloud::k8s_utils;
use base Exporter;
use testapi;
use warnings;
use strict;

our @EXPORT = qw(install_kubectl wait_for_container_log create_manifest);

=head2 install_kubectl
Install kubectl from the k8s page
=cut
sub install_kubectl {
  my $version = "v1.22.2";
  assert_script_run("curl -LO https://dl.k8s.io/release/$version/bin/linux/amd64/kubectl");
  assert_script_run("chmod a+x kubectl");
  assert_script_run("rm /usr/bin/kubectl");
  assert_script_run("mv kubectl /usr/bin/kubectl");
}

=head2 wait_for_container_log
Waits for an especific log outut or die (afeter a timeout)
=cut
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

=head2 create_manifest
Creates a manifest from a string content
=cut
sub create_manifest {
    my ($content) = @_;
    my $filename = `cat /proc/sys/kernel/random/uuid | tr -d '\n'`.'.yaml';
    my $path = "/tmp/$filename";

    save_tmp_file($filename, $content);
    assert_script_run(sprintf('curl -o "%s" "%s/files/%s"', $path, autoinst_url, $filename));
    $path;
}

1;
