use 5.006;    # our
use strict;
use warnings;

package branchfilter;

our $VERSION = '0.001000';

use File::Spec;
use Cwd qw( abs_path );
use Git::Repository;
use Git::FastExport;
use Clone qw( clone );

# ABSTRACT: Filter branch(es) to generate derived braches

# AUTHORITY

our %BLOCK_TYPES = (map {$_ => 1} qw(commit tag reset blob checkpoint progress feature option done));

sub new {
  my ($self, $args) = ((bless {}, $_[0]), ref $_[1] ? {%{$_[1]}} : {@_[1 .. $#_]});

  exists $args->{branches}    ? $self->_set_branches(delete $args->{branches})       : $self->_set_branches(['master']);
  exists $args->{source_repo} ? $self->_set_source_repo(delete $args->{source_repo}) : $self->_set_source_repo('.');
  grep {exists $args->{$_}} qw( handlers prune_empty write ) and $self->_add_handler({
                             dest_repo => $self->dest_repo,
                             map {exists $args->{$_} ? ($_ => delete $args->{$_}) : ()} qw( handlers prune_empty write )
  });
  keys %{$args} and die "Unknown constructer argments [ @{[ keys %{$args} ]} ]";
  return $self;
}

sub branches  {@{$_[0]->{branches}  || []}}
sub _handlers {@{$_[0]->{_handlers} || []}}

sub dest_repo   {$_[0]->{dest_repo}}
sub source_repo {$_[0]->{source_repo}}

sub next_block {
  my $object = $_[0]->_git_fastexport->next_block;
  return if not defined $object;
  $_->_handle_block(clone($object)) for $_[0]->_handlers;
  return $object;
}

sub _set_source_repo {
  defined $_[1] or die "source_repo must be a defined value";
  length $_[1]  or die "source_repo must have a length";
  -d $_[1]      or die "source_repo must be a valid directory";
  $_[0]->{source_repo} = File::Spec->rel2abs($_[1]);
  $_[0]->{dest_repo}   = $_[0]->{source_repo};
}

sub _set_branches {
  defined $_[1]        or die "branches must be a defined value";
  ref $_[1]            or die "branches must be a REF";
  'ARRAY' eq ref $_[1] or die "branches must be an ARRAY ref";
  $_[0]->{branches} = [@{$_[1]}];
}

sub _add_handler {
  my ($self, $args) = (($_[0]), ref $_[1] ? {%{$_[1]}} : {@_[1 .. $#_]});
  $args->{dest_repo} = $self->dest_repo unless exists $args->{dest_repo};
  require branchfilter::handler;
  push @{$_[0]->{_handlers}}, branchfilter::handler->new($args);
}

sub _git_source {
  exists $_[0]->{_git_source} ? $_[0]->{_git_source} : $_[0]->{_git_source} =
    Git::Repository->new(work_tree => $_[0]->source_repo);
}

sub _git_export {
  exists $_[0]->{_git_export}
    or $_[0]->{_git_export} =
    $_[0]->_git_source->command('fast-export', '--progress=1000', '--no-data', '--date-order', $_[0]->branches)->stdout;
  $_[0]->{_git_export};
}

sub _git_fastexport {
  exists $_[0]->{_git_fastexport} or $_[0]->{_git_fastexport} = Git::FastExport->new($_[0]->_git_export);
  $_[0]->{_git_fastexport};
}

1;
