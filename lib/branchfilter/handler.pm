use 5.006;    # our
use strict;
use warnings;

package branchfilter::handler;

our $VERSION = '0.001000';

# ABSTRACT: Abstract dispatch of branch decodes

# AUTHORITY

use branchfilter::util qw/ _lazy_get _lazy_constructor %BLOCK_TYPES/;

sub new {
  return _lazy_constructor({optional => [qw( dest_repo encoder handlers prune_empty write marks namespace )],}, @_);
}

sub dest_repo   {_lazy_get($_[0], 'dest_repo')}
sub encoder     {_lazy_get($_[0], 'encoder')}
sub marks       {_lazy_get($_[0], 'marks')}
sub handlers    {_lazy_get($_[0], 'handlers')}
sub prune_empty {_lazy_get($_[0], 'prune_empty')}
sub write       {_lazy_get($_[0], 'write')}
sub namespace   {_lazy_get($_[0], 'namespace')}

sub _normalize_dest_repo   {File::Spec->rel2abs($_[1])}
sub _normalize_namespace   {"$_[1]"}
sub _normalize_prune_empty {!!$_[1]}
sub _normalize_write       {!!$_[1]}

sub _default_dest_repo {'.'}
sub _default_encoder   {require branchfilter::encoder; branchfilter::encoder::->new(marks => $_[0]->marks)}
sub _default_handlers  {{}}
sub _default_marks {require branchfilter::marks; branchfilter::marks::->new()}
sub _default_namespace   {'main'}
sub _default_prune_empty {1}
sub _default_write       {0}

sub _validate_dest_repo {
  defined $_[1] or die "dest_repo must be a defined value";
  length $_[1]  or die "dest_repo must have a length";
  -d $_[1]      or die "dest_repo must be a valid directory";
}

sub _validate_handlers {
  defined $_[1]       or die "handlers must be a defined value";
  ref $_[1]           or die "handlers must be a REF";
  'HASH' eq ref $_[1] or die "handlers must be a HASH ref";
  my (@unknown) = grep {not exists $BLOCK_TYPES{$_}} keys %{$_[1]};
  die "unknown handler names: @unknown" if @unknown;
}

sub handle_block {
  my ($self, $block, $info) = @_;
  $info = {} if not defined $info;

  # optimization
  my $handlers = exists $self->{handlers} ? $self->{handlers} : $self->handlers();
  my $encoder  = exists $self->{encoder}  ? $self->{encoder}  : $self->encoder();
  if (exists $handlers->{$block->{type}}) {
    local $info->{marks}     = exists $self->{marks}     ? $self->{marks}     : $self->marks;
    local $info->{namespace} = exists $self->{namespace} ? $self->{namespace} : $self->namespace;
    $handlers->{$block->{type}}->($self, $block, $info);
  }
  $encoder->encode_block($block, $info);
  return if $info->{skip};
  $self->_git_write_block($_[1]);
}

sub _git_write_block {
  return unless $_[0]->write;
  exists $_[0]->{write_inited} or do {
    $_[0]->{write_inited} = 1;
    open $_[0]->{write_fh}, '|-', 'git', '-C', $_[0]->dest_repo, 'fast-import' or die "Can't spawn fast-import, $@ $!";
  };
  $_[0]->{write_fh}->print($_[1]->as_string) or die "Could not write $_[1]->{type} to git-fast-import";
}

sub DESTROY {
  return unless ref $_[0];
  exists $_[0]->{write_inited} and (close $_[0]->{write_fh} or warn "error closing git, $?");
}

1;

