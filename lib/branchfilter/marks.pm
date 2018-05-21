use 5.006;    # our
use strict;
use warnings;

package branchfilter::marks;

our $VERSION = '0.001000';

# ABSTRACT: Database of marks and translations

# AUTHORITY

sub new {
  my ($self, $args) = ((bless {}, $_[0]), ref $_[1] ? {%{$_[1]}} : {@_[1 .. $#_]});
  keys %{$args} and die "Unknown constructer argments [ @{[ keys %{$args} ]} ]";
  $self->{marks}      = {};
  $self->{from}       = {};
  $self->{merge}      = {};
  $self->{namespaces} = {};
  return $self;
}

sub set_lastmark {
  my ($self, $branch, $mark) = @_;
  $self->{marks}->{$branch} = $mark;
}

sub get_lastmark {
  my ($self, $branch) = @_;
  exists $self->{marks}->{$branch} and return $self->{marks}->{$branch};
  die "Unknown lastmark for $branch";
}

sub set_mark_from {
  my ($self, $mark, $from_mark) = @_;
  $self->{from}->{$mark} = $from_mark;
}

sub set_mark_merge {
  my ($self, $mark, @merge) = @_;
  $self->{merge}->{$mark} = \@merge;
}

sub set_mark_skip {
  my ($self, $namespace, $mark) = @_;
  $self->_namespace($namespace)->{skip}->{$mark} = 1;
}

sub get_translated_mark {
  my ($self, $namespace, $mark) = @_;
  my $ns = $self->_namespace($namespace);

  return $mark unless exists $ns->{skip}->{$mark};
  return undef unless exists $self->{from}->{$mark};
  return $self->get_translated_mark($namespace, $self->{from}->{$mark});
}

sub get_newmark {
  my ($self, $namespace, $oldmark) = @_;
  my $ns = $self->_namespace($namespace);

  # Cached response
  return $ns->{translations}->{$oldmark} if exists $ns->{translations}->{$oldmark};

  # Calculate cached response
  my $reso_oldmark = $self->get_translated_mark($namespace, $oldmark);

  # From graph ultimately ends as "new branch"
  if (not defined $reso_oldmark) {
    $ns->{translations}->{$oldmark} = undef;
    return undef;
  }

  # From graph ultimately ends in a translated parent previously re-marked
  # cache that result and return it.
  if (defined $reso_oldmark and exists $ns->{translations}->{$reso_oldmark}) {
    $ns->{translations}->{$oldmark} = $ns->{translations}->{$reso_oldmark};
    return $ns->{translations}->{$reso_oldmark};
  }

  # Node previously unseen in translation table and maps to neither a branch
  # root, or a previous mark
  $ns->{last_idx}++;
  $ns->{translations}->{$oldmark} = $ns->{last_idx};
  return $ns->{last_idx};
}

sub _namespace {
  exists $_[0]->{namespaces}->{$_[1]}
    or $_[0]->{namespaces}->{$_[1]} = {skip => {}, last_idx => 0, translations => {},};
  return $_[0]->{namespaces}->{$_[1]};
}

1;

