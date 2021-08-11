# Copyright © 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Override known failures for QAM
# Maintainer: Jan Baier <jbaier@suse.cz>

package LTP::WhiteList;

use base Exporter;
use strict;
use warnings;
use testapi;
use bmwqemu;
use Exporter;
use Mojo::UserAgent;
use Mojo::JSON;
use Mojo::File 'path';

our @EXPORT = qw(download_whitelist override_known_failures is_test_disabled);

sub download_whitelist {
    my $path = get_var('LTP_KNOWN_ISSUES');
    return undef unless defined($path);

    my $res = Mojo::UserAgent->new->get($path)->result;
    unless ($res->is_success) {
        record_info("File not downloaded!", $res->message, result => 'softfail');
        set_var('LTP_KNOWN_ISSUES', undef);
    }
    my $basename = $path =~ s#.*/([^/]+)#$1#r;
    save_tmp_file($basename, $res->body);
    set_var('LTP_KNOWN_ISSUES', hashed_string($basename));
    mkdir('ulogs') if (!-d 'ulogs');
    bmwqemu::save_json_file($res->json, "ulogs/$basename");
}

sub find_whitelist_testsuite {
    my ($env, $suite) = @_;

    my $path = get_var('LTP_KNOWN_ISSUES');
    return undef unless defined($path) or !-e $path;

    my $content = path($path)->slurp;
    my $issues  = Mojo::JSON::decode_json($content);
    return undef unless $issues;
    return $issues->{$suite};
}

sub list_skipped_tests {
    my ($env, $suite) = @_;
    my @skipped_tests;
    $suite = find_whitelist_testsuite($env, $suite);

    die 'Unsupported format for `list_skipped_tests()`' if (ref($suite) eq 'ARRAY');

    for my $test (keys(%$suite)) {
        my @entrys = grep { $_->{skip} && whitelist_entry_match($_, $env) } @{$suite->{$_}};
        push @skipped_tests, $test if @entrys;
    }
    return @skipped_tests;
}

sub whitelist_entry_match
{
    my ($entry, $env) = @_;
    my @mandatory_attributes = qw(product ltp_version revision arch kernel backend retval flavor);

    die("Given environment is missing one of the following attributes: @mandatory_attributes") if grep { !exists $env->{$_} } @mandatory_attributes;

    foreach my $attr (@mandatory_attributes) {
        return undef if (exists $entry->{$attr} && $env->{$attr} !~ m/$entry->{$attr}/);
    }
    return $entry;
}

sub find_whitelist_entry {
    my ($env, $suite, $test) = @_;

    $suite = find_whitelist_testsuite($env, $suite);

    my @issues;
    if (ref($suite) eq 'ARRAY') {
        @issues = @{$suite};
    }
    else {
        $test =~ s/_postun$//g if check_var('KGRAFT', 1) && check_var('UNINSTALL_INCIDENT', 1);
        return undef unless exists $suite->{$test};
        @issues = @{$suite->{$test}};
    }

    foreach my $cond (@issues) {
        return $cond if (whiltelist_entry_match($cond, $env));
    }

    return undef;
}

sub override_known_failures {
    my ($self, $env, $suite, $test) = @_;
    my $entry = find_whitelist_entry($env, $suite, $test);

    return 0 unless defined($entry);
    bmwqemu::diag("Failure in LTP:$suite:$test is known, overriding to softfail");
    $self->{result} = 'softfail';
    $self->record_soft_failure_result($entry->{message}) if exists $entry->{message};
    return 1;
}

sub is_test_disabled {
    my $entry = find_whitelist_entry(@_);

    return 1 if defined($entry) && exists $entry->{skip} && $entry->{skip};
    return 0;
}

1;
