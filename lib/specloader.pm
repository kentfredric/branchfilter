use 5.006;    # our
use strict;
use warnings;

package specloader;

our $VERSION = '0.001000';

use File::Spec;
use Cwd qw( abs_path );

# ABSTRACT: load spec files

# AUTHORITY

{
  package    # hide me
    proto;
  $INC{'proto.pm'} = __FILE__;

  sub import {
    my $caller = caller;
    my $stash = do {no strict 'refs'; \%{$caller . '::'};};

    # Callback constructs exports for whatever uses 'use proto'
    specloader::_load_file(specloader::_proto($_[1]))
      ->($stash, {note => sub {*STDERR->print("$_\n") for @_}, register_filter => \&specloader::register_filter,});
    specloader::_push_register($stash->{register}) if exists $stash->{register};
  }
}
our (@reg_todo);

sub import {
  local @reg_todo = ();
  _load_file(_spec($_[1]));
  _process_registrations();
}

my %filters = (tree_filters => [], commit_filters => [],);

sub register_filter {
  my ($filter) = @_;
  push @{$filters{tree_filters}},   $filter->{tree_filter};
  push @{$filters{commit_filters}}, $filter->{commit_filter};
}

# HACK
# This works around the inability for 'specloader' to know what the name
# of any class is inside a given spec file by allowing the 'proto' package
# to stash a reference to any of the subs called 'register' that exist
# in the target stash after executing its import.
#
# Thus:
#   require spec -> 
#     require proto ->
#       proto defines register in stash
#       <-
#     records reference to register in specloader
#     rest of spec executes
#     <-
#   registered references in specloader are run
#     -> proto's injected register method is called
sub _push_register {push @reg_todo, $_[0]}

sub _process_registrations {
  while (@reg_todo) {(shift @reg_todo)->()}
}

## PATH RESOLVER TOOLS
# Resolve real path to project root without being subject to random CWD changes
use constant _REAL_ROOT => abs_path(__FILE__) =~ m{\A(.*?/)[^/]+/[^/]+\z};
sub _path_proto {_REAL_ROOT . $_[0] . '/proto/' . ($_[1] || '')}    # Namespaced proto dir
sub _path_spec  {_REAL_ROOT . $_[0] . '/spec/' .  ($_[1] || '')}    # Namespaced spec dir
sub _proto {(_path_proto($_[0] =~ m{\A([^/]+)/(.*)}) || '') . '.pl'}    # proto('x/y') -> '{root}/x/proto/y.pl'

sub _spec {
  $_[0] =~ /\A=(.*)\z/
    ? File::Spec->rel2abs($1)                                           # spec('=x/y') -> 'abs/path/x/y'
    : ((_path_spec($_[0] =~ m{\A([^/]+)/(.*)}) || '') . '.pl');         # spec('x/y') -> '{root}/x/spec/y.pl'
}

## FILE LOADING TOOLS
sub _load_file {
  local ($@, $!);
  my $result = do $_[0];
  die "can't parse $_[0]: $@, $!" if $@;
  die "No return value from $_[0], $!" unless defined $result;
  return $result;
}

1;

