#!perl
use strict;
use warnings;
return sub {
  my ($stash, $tools) = @_;
  my $state = {};
  $stash->{add_source_branch} = sub {push @{$state->{source_branches}}, @_};
  $stash->{parse_ebuild} = sub {
    my ($in) = @_;
    if ($in =~ m{\A([^/]+)/([^/]+)/([^/]+)\.ebuild\z}) {
      my ($category, $package, $ebuild) = ($1, $2, $3);
      $ebuild =~ s/\A\Q${package}\E-//;
      return ($category, $package, $ebuild);
    }
    return;
  };
  $stash->{add_ebuild} = sub {
    my ($in, $out,) = @_;
    my ($category, $package, $version) = $stash->{parse_ebuild}($in);
    die "Can't parse $in" if not defined $category;
    defined $out or $out = "${category}/${package}.ebuild";
    $state->{transforms}->{"$in"} = $out;
    return ($category, $package, $version);
  };
  $stash->{map_ebuild} = sub {
    my ($in, $out,) = @_;
    my ($category, $package, $version) = $stash->{add_ebuild}($in);
    $stash->{category}($category);
    $stash->{package}($package);
    $stash->{version}($version);
  };
  $stash->{category} = sub {
    if (@_) {
      die "category already set" if exists $state->{category};
      $state->{category} = $_[0];
    }
    exists $state->{category} or die "category not set";
    return $state->{category};
  };
  $stash->{package} = sub {
    if (@_) {
      die "package already set" if exists $state->{package};
      $state->{package} = $_[0];
    }
    exists $state->{package} or die "package not set";
    return $state->{package};
  };
  $stash->{version} = sub {
    if (@_) {
      die "version already set" if exists $state->{version};
      $state->{version} = $_[0];
    }
    exists $state->{version} or die "version not set";
    return $state->{version};
  };
  $stash->{ebuild} = sub {
    return
        $stash->{category}() . '/'
      . $stash->{package}() . '/'
      . $stash->{package}() . '-'
      . $stash->{version}()
      . '.ebuild';
  };
  $stash->{atom} = sub {$stash->{category}() . '/' . $stash->{package}() . '-' . $stash->{version}()};
  $stash->{add_include_regex} = sub {push @{$state->{include}}, @_;};
  $stash->{add_includes} = sub {
    $stash->{add_include_regex}(map {qr{\A\Q$_\E\z}} @_);
  };
  $stash->{add_files} = sub {
    $stash->{add_includes}(map {$stash->{category}() . '/' . $stash->{package}() . '/files/' . $_} @_);
  };
  $stash->{is_included} = sub {
    for my $re (@{$state->{include} || []}) {$_[0] =~ $re and return 1}
    return;
  };
  $stash->{source_branches} = sub {@{$state->{source_branches} || ['master']}};
  $stash->{dump_state} = sub {require Data::Dumper; *STDERR->print(Data::Dumper::Dumper($state));};
  my ($registered);
  $stash->{register} = sub {
     return if $registered;
     $registered = 1;
    $tools->{note}((sprintf "generating \e[32m%s\e[0m", $stash->{atom}()),
                   " from:",
                   (map {sprintf "   %s \e[32m=>\e[0m %s", $_, $state->{transforms}->{$_}}
                    sort keys %{$state->{transforms} || {}}),
                   " including:",
                   (map {sprintf "   %s", $_} sort @{$state->{include} || []}),
                   " reading:",
                   (map {sprintf "   %s", $_} sort $stash->{source_branches}()));
    my ($fileset) = {};
    $tools->{register_filter}({
     tree_filter => sub {
       my ($type, $path, $data, $raw) = @_;
       for my $key (sort keys %{$state->{transforms} || {}}) {
         next unless $path eq $key;
         my $newname = $state->{transform}->{$key};
         $raw =~ s/[ ]\Q\$key\E\z/ $newname/;
         $fileset->{$newname} = $type;
         return ($raw);
       }
       for my $re (@{$state->{include} || []}) {
         next unless $path =~ $re;
         $fileset->{$path} = $type;
         return ($raw);
       }
       return;
     },
     commit_filter => sub {
       my ($block)      = @_;
       my $maybe_prefix = $stash->{category}() . '/' . $stash->{package} . ': ';
       my $message      = $block->{data};
       $message =~ s/\A\Q$maybe_prefix\E//;
       $block->{data} = $stash->{atom}() . ': ' . $message;
       return $block;
     },
    });
  };
};
