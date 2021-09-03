use Mojo::Base -strict;
use Data::Dumper;

sub get_opensuse_registry_prefix {
    return 'open_suse_registry_prefix_XXX'. join('+', @_);
}

my $registries = {
    sle => {
      '12-SP3' => {
            'x86_64|ppc64le|s390x' => {
                released => 'registry.suse.com/suse/sles12sp3' ,
                totest   => 'registry.suse.de/suse/sle-12-sp3/docker/update/cr/totest/images/suse/sles12sp3'
            },
        },
        '12-SP4' => { 
            'x86_64|ppc64le|s390x' => { 
                released => 'registry.suse.com/suse/sles12sp4',
                totest   => 'registry.suse.de/suse/sle-12-sp4/docker/update/cr/totest/images/suse/sles12sp4',
            }

        }
    },

    opensuse => {
        Tumbleweed => { 
            'x86_64|aarch64|ppc64le|s390x|arm' =>  {
                released => 'registry.opensuse.org/opensuse/tumbleweed',
                totest   => sub { 'registry.opensuse.org/' . get_opensuse_registry_prefix(@_) . 'opensuse/tumbleweed'}
            },
        },
        '15.1' => {
            'x86_64' => {
                released => 'registry.opensuse.org/opensuse/leap:15.1',
                totest   => 'registry.opensuse.org/opensuse/leap/15.1/images/totest/containers/opensuse/leap:15.1',
            },
            'arm' => {
                released => 'registry.opensuse.org/opensuse/leap:15.1',
                totest => 'registry.opensuse.org/opensuse/leap/15.1/arm/images/totest/containers/opensuse/leap:15.1',
            }
        }
    },
};

sub __find_key {
    my ($hash, $needle) = @_;
    my @ret;

    for my $k (keys %$hash){
        if (grep {$_ eq $needle } split(/\|/, $k)){
            push (@ret, $k);
        }
    }
    die "The key $needle does not return unique entry!" if @ret > 1;
    return @ret ? $hash->{$ret[0]} : undef;
}
# Returns a tuple of image urls and their matching released "stable" counterpart.
# If empty, no images available.
sub get_suse_container_urls {
    my (%args) = @_;
    $args{version} //= get_required_var('VERSION');
    $args{arch}    //= get_required_var('ARCH');
    $args{distri}  //= get_required_var('DISTRI');
    my @totest = ();
    my @released = ();

    my $distri = __find_key($registries, $args{distri});
    unless($distri){
        say 'ERROR: didn\'t found matching entry for '. $args{distri};
        return (\@totest, \@released);
    }

    my $version = __find_key($distri, $args{version});
    unless($version){
        say 'ERROR: didn\'t found matching entry for '. join('->', $args{distri}, $args{version});
        return (\@totest, \@released);
    }

    my $arch = __find_key($version, $args{arch});
    unless($arch){
        say 'ERROR: didn\'t found matching entry for '. join('->', $args{distri}, $args{version}, $args{arch});
        return (\@totest, \@released);
    }

    if (ref($arch->{totest}) eq 'CODE'){
        push @totest, $arch->{totest}->(%args);
    } else {
        push @totest, $arch->{totest};
    }

    if (ref($arch->{released}) eq 'CODE'){
        push @released, $arch->{released}->(%args);
    } else {
        push @released, $arch->{released};
    }

    return (\@totest, \@released);
}


say Dumper([get_suse_container_urls (version => '12-SP3', distri=> 'sle', arch=>'x86_64')]);
say Dumper([get_suse_container_urls (distri=> 'opensuse', version => 'Tumbleweed',  arch=>'x86_64')]);
