use 5.006;    # our
use strict;
use warnings;

package branchfilter;

our $VERSION = '0.001000';

use File::Spec;
use Cwd qw( abs_path );
use Git::Repository;
use Git::FastExport;
use branchfilter::util qw/ _lazy_get _lazy_constructor /;

# ABSTRACT: Filter branch(es) to generate derived braches

# AUTHORITY

sub new {
  return _lazy_constructor({optional => [qw( prune_empty write handlers branches source_repo )]}, @_);
}

sub branches {@{_lazy_get($_[0], 'branches')}}
sub handlers {@{_lazy_get($_[0], 'handlers')}}
sub decoder         {_lazy_get($_[0], 'decoder')}
sub marks           {_lazy_get($_[0], 'marks')}
sub dest_repo       {_lazy_get($_[0], 'dest_repo')}
sub source_repo     {_lazy_get($_[0], 'source_repo')}
sub _git_source     {_lazy_get($_[0], '_git_source')}
sub _git_export     {_lazy_get($_[0], '_git_export')}
sub _git_fastexport {_lazy_get($_[0], '_git_fastexport')}

sub _default_prune_empty     {1}
sub _default_write           {!1}
sub _default_branches        {['master']}
sub _default_handlers        {[]}
sub _default_source_repo     {'.'}
sub _default_dest_repo       {$_[0]->source_repo}
sub _default_decoder         {require branchfilter::decoder; branchfilter::decoder::->new()}
sub _default_marks           {require branchfilter::marks; branchfilter::marks::->new()}
sub _default__git_source     {Git::Repository->new(work_tree => $_[0]->source_repo)}
sub _default__git_fastexport {Git::FastExport->new($_[0]->_git_export)}

sub _default__git_export {
  $_[0]->_git_source->command('fast-export', '--progress=1000', '--no-data', '--date-order', $_[0]->branches)->stdout;
}

sub _normalize_source_repo {File::Spec->rel2abs($_[1])}
sub _normalize_dest_repo   {File::Spec->rel2abs($_[1])}
sub _normalize_branches    {[@{$_[1]}]}

sub _coerce_handlers {
  my ($self, $handlers) = @_;
  if ('ARRAY' ne ref $handlers) {
    $handlers = [$handlers];
  }
  my @out;
  for my $handler (@{$handlers}) {
    if ('HASH' ne ref $handler) {
      push @out, $handler;
      next;
    }
    require branchfilter::handler;
    push @out,
      branchfilter::handler->new((exists $handler->{dest_repo} ? () : (dest_repo => $self->dest_repo)), %{$handler});
  }
  return \@out;
}

my %is_change = (changes => 1);
my %is_author = (author => 1, committer => 1);

sub next_block {
  my ($self) = @_;
  my $object = (exists $self->{_git_fastexport} ? $self->{_git_fastexport} : $self->_git_fastexport)->next_block;
  return if not defined $object;
  my ($info) = {};
  (exists $self->{decoder} ? $self->{decoder} : $self->decoder)->decode_block($object, $info);
  for my $handler ($self->handlers) {

    # Turns out, this garbage is faster than XS clone.
    my $cloned_block =
      bless {map {ref $object->{$_} ? ($_ => [@{$object->{$_}}]) : ($_ => $object->{$_})} keys %{$object}},
      "Git::FastExport::Block";

    my $cloned_info = {
      map {
        $_ => (  exists $is_change{$_} ? [map {[$_->[0], $_->[1], {%{$_->[2]}}]} @{$info->{$_}}]
               : exists $is_author{$_} ? {%{$info->{$_}}}
               :                         $info->{$_})
      } keys %{$info}};

    $handler->handle_block($cloned_block, $cloned_info);
  }
  return $object;
}

sub _add_handler {
  my ($self, $args) = (($_[0]), ref $_[1] ? {%{$_[1]}} : {@_[1 .. $#_]});
  $args->{dest_repo} = $self->dest_repo unless exists $args->{dest_repo};
  require branchfilter::handler;
  push @{_lazy_get($self, 'handlers')}, branchfilter::handler->new($args);
}

sub _validate_source_repo {
  defined $_[1] or die "source_repo must be a defined value";
  length $_[1]  or die "source_repo must have a length";
  -d $_[1]      or die "source_repo must be a valid directory";
}

sub _validate_dest_repo {
  defined $_[1] or die "dest_repo must be a defined value";
  length $_[1]  or die "dest_repo must have a length";
  -d $_[1]      or die "dest_repo must be a valid directory";
}

sub _validate_branches {
  defined $_[1]        or die "branches must be a defined value";
  ref $_[1]            or die "branches must be a REF";
  'ARRAY' eq ref $_[1] or die "branches must be an ARRAY ref";
}
1;
