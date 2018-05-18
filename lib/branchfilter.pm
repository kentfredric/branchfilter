use 5.006;    # our
use strict;
use warnings;

package branchfilter;

our $VERSION = '0.001000';

use File::Spec;
use Cwd qw( abs_path );
use Git::Repository;
use Git::FastExport;

# ABSTRACT: Filter branch(es) to generate derived braches

# AUTHORITY

our %BLOCK_TYPES = (map {$_ => 1} qw(commit tag reset blob checkpoint progress feature option done));

sub new {
  my ($self, $args) = ((bless {}, $_[0]), ref $_[1] ? {%{$_[1]}} : {@_[1 .. $#_]});

  exists $args->{branches}    ? $self->_set_branches(delete $args->{branches})       : $self->_set_branches(['master']);
  exists $args->{handlers}    ? $self->_set_handlers(delete $args->{handlers})       : $self->_set_handlers({});
  exists $args->{prune_empty} ? $self->_set_prune_empty(delete $args->{prune_empty}) : $self->_set_prune_empty(1);
  exists $args->{source_repo} ? $self->_set_source_repo(delete $args->{source_repo}) : $self->_set_source_repo('.');
  exists $args->{write}       ? $self->_set_write(delete $args->{write})             : $self->_set_write(0);
  $self->_init_stats();
  $self->_init_state();
  keys %{$args} and die "Unknown constructer argments [ @{[ keys %{$args} ]} ]";
  return $self;
}

sub branches {@{$_[0]->{branches} || []}}
sub dest_repo   {$_[0]->{dest_repo}}
sub prune_empty {$_[0]->{prune_empty}}
sub source_repo {$_[0]->{source_repo}}
sub write       {$_[0]->{write}}

sub next_block {
  my $object = $_[0]->_git_fastexport->next_block;
  return if not defined $object;
  $_[0]->_handle_block($object);
  return $object;
}

sub stats {
  my (@out);
  for my $key (qw( commit blob )) {
    push @out, sprintf "%s: %8d => %8d", $key, $_[0]->{stats}->{in}->{$key}, $_[0]->{stats}->{out}->{$key};
  }
  return join q[, ], @out;
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
sub _set_write       {$_[0]->{write}       = !!$_[1]}
sub _set_prune_empty {$_[0]->{prune_empty} = !!$_[1]}

sub _set_handlers {
  defined $_[1]       or die "handlers must be a defined value";
  ref $_[1]           or die "handlers must be a REF";
  'HASH' eq ref $_[1] or die "handlers must be a HASH ref";
  my $args = {%{$_[1]}};
  for my $handler (sort keys %BLOCK_TYPES) {
    $_[0]->{handlers}->{$handler} = delete $args->{$handler} if exists $args->{$handler};
  }
  die "unknown handler names: @{[ keys %{$args} ]}" if keys %{$args};
}

sub _init_state {$_[0]->{state} = {}}
sub _stat_in    {$_[0]->{stats}->{in}->{$_[1]->{type}}++}
sub _stat_out   {$_[0]->{stats}->{out}->{$_[1]->{type}}++}

sub _init_stats {
  $_[0]->{stats} = {in => {map {$_ => 0} keys %BLOCK_TYPES}, out => {map {$_ => 0} keys %BLOCK_TYPES},};
}

sub _preprocess_block {
  $_[0]->_stat_in($_[1]);
  my $cb = $_[0]->can('_preprocess_' . $_[1]->{type});
  $cb and $_[0]->$cb($_[1], $_[2]);
}

sub _postprocess_block {
  my $cb = $_[0]->can('_postprocess_' . $_[1]->{type});
  $cb and $_[0]->$cb($_[1], $_[2]);
  $_[2]->{skip} and return;
  $_[0]->_git_write_block($_[1]);
  $_[0]->_stat_out($_[1]);
}

sub _handle_block {
  my $info = {};
  $_[0]->_preprocess_block($_[1], $info);
  exists $_[0]->{handlers}->{$_[1]->{type}} and $_[0]->{handlers}->{$_[1]->{type}}->($_[0], $_[1], $info);
  $_[0]->_postprocess_block($_[1], $info);
}

sub _preprocess_commit {
  my ($self, $block, $info) = @_;
  $info->{changes} = [];

  if ($block->{header} =~ m{\Acommit \x20 (.*)\z}x) {
    $info->{branch} = $1;
  }

  for my $file (@{$block->{files}}) {
    if ($file =~ m/\AM \x20 (.*?) \x20 (.*?) \x20 (.*?) \z/x) {
      push @{$info->{changes}}, ['M', $3, {mode => $1, ref => $2, raw => $file}];
      next;
    }
    if ($file =~ m/\AD \x20 (.*?) \z/x) {
      push @{$info->{changes}}, ['D', $1, {raw => $file}];
      next;
    }
    if ($file =~ m/\AC \x20 (.*?) \x20 (.*?)\z/) {
      push @{$info->{changes}}, ['C', $2, {source => $1, raw => $file}];
      next;
    }

    # Convert renames into Copy + Delete pairs
    # We'd do this with just M + D if we could, but the data isn't there
    # Same for "C"
    if ($file =~ m/\AR \x20 (.*?) \x20 (.*?)\z/) {
      push @{$info->{changes}}, ['C', $2, {source => $1, raw => sprintf "C %s %s", $1, $2}];
      push @{$info->{changes}}, ['D', $1, {raw => sprintf "D %s", $1}];
      next;
    }
    if ($file eq 'deleteall') {
      push @{$info->{changes}}, ['deleteall', undef, {raw => $file}];
      next;
    }
    if ($file =~ /\AN \x20 (.*?) \x20 (.*?)\z/) {
      warn "Note found \e[31;1m(unsupported)\e[0m\n";
      next;
    }
  }
  @{$block->{from}  || []} and $block->{from}->[0] =~ /\Afrom \x20 (.*?)\z/   and $info->{from}  = $1;
  @{$block->{mark}  || []} and $block->{mark}->[0] =~ /\Amark \x20 (.*?)\z/   and $info->{mark}  = $1;
  @{$block->{merge} || []} and $block->{merge}->[0] =~ /\Amerge \x20 (.*?)\z/ and $info->{merge} = $1;

  $info->{from}  = $self->_translate_oldmark($info->{from})  if exists $info->{from};
  $info->{merge} = $self->_translate_oldmark($info->{merge}) if exists $info->{merge};

  {
    my ($aname, $aemail, $dt, $tz,) = $block->{author}->[0] =~ qr{
                  \A
      author      \x20
      ([^<]*?)    \x20
      <([^>]*?)>  \x20
      (\d+)       \x20
      ([-+]\d+)   \z
    }x;
    $info->{author}->{name}   = $aname;
    $info->{author}->{email}  = $aemail;
    $info->{author}->{'time'} = $dt;
    $info->{author}->{tz}     = $tz;
  }
  {
    my ($cname, $cemail, $dt, $tz,) = $block->{committer}->[0] =~ qr{
                  \A
      committer   \x20
      ([^<]*?)    \x20
      <([^>]*?)>  \x20
      (\d+)       \x20
      ([-+]\d+)   \z
    }x;
    $info->{committer}->{name}   = $cname;
    $info->{committer}->{email}  = $cemail;
    $info->{committer}->{'time'} = $dt;
    $info->{committer}->{tz}     = $tz;
  }

  delete $info->{from}  if not defined $info->{from};
  delete $info->{merge} if not defined $info->{merge};

}

sub _postprocess_commit {
  my ($self, $block, $info) = @_;
  $block->{files} = [];
  exists $info->{branch} and $block->{header} = sprintf 'commit %s', $info->{branch};
  for my $change (@{$info->{changes}}) {
    if (not $change->[0] eq 'deleteall' and not defined $change->[2]->{raw}) {
      if ($change->[0] eq 'M') {
        push @{$block->{files}}, sprintf 'M %s %s %s', $change->[2]->{mode}, $change->[2]->{ref}, $change->[1];
        next;
      }
      if ($change->[0] eq 'D') {
        push @{$block->{files}}, sprintf 'D %s', $change->[1];
        next;
      }
      if ($change->[0] eq 'C') {
        push @{$block->{files}}, sprintf 'C %s %s', $change->[2]->{source}, $change->[1];
        next;
      }
      die "Unknown change type $change->[0], cannot reconstruct data";
    }
    push @{$block->{files}}, $change->[2]->{raw};
  }
  if (not @{$block->{files}} and $self->prune_empty and not exists $info->{merge}) {
    $info->{skip} = 1;
    if (exists $info->{mark}) {
      $self->_replace_oldmark($info->{mark}, $info->{from});
    }
  }

  if (exists $info->{author}) {
    $block->{author} = [sprintf "author %s <%s> %s %s", $info->{author}->{name}, $info->{author}->{email},
                        $info->{author}->{'time'},      $info->{author}->{tz}];
  }
  if (exists $info->{committer}) {
    $block->{committer} = [sprintf "committer %s <%s> %s %s", $info->{committer}->{name},
                           $info->{committer}->{email},       $info->{committer}->{'time'},
                           $info->{committer}->{tz}];
  }

  unless ($info->{skip}) {
    delete $block->{from}; exists $info->{from}
      and $block->{from} = [sprintf 'from %s', $self->_get_newmark($info->{from})];
    delete $block->{mark}; exists $info->{mark}
      and $block->{mark} = [sprintf 'mark %s', $self->_get_newmark($info->{mark})];
    delete $block->{merge}; exists $info->{merge}
      and $block->{merge} = [sprintf 'merge %s', $self->_get_newmark($info->{mark})];
  }
}

sub _get_newmark {
  $_[0]->{mark_idx} = 0 unless exists $_[0]->{mark_idx};
  return $_[0]->{replacements}->{new}->{$_[1]} if exists $_[0]->{replacements}->{new}->{$_[1]};
  $_[0]->{mark_idx}++;
  $_[0]->{replacements}->{new}->{$_[1]} = ":" . $_[0]->{mark_idx};
  return ":" . $_[0]->{mark_idx};
}

sub _replace_oldmark {
  my ($self, $orig_oldmark, $new_oldmark) = @_;
  my $newmark = $self->_get_newmark($new_oldmark);
  $_[0]->{replacements}->{old}->{$orig_oldmark} = $new_oldmark;
}

sub _translate_oldmark {
  my ($self, $oldmark) = @_;
  return $oldmark unless exists $_[0]->{replacements}->{old}->{$oldmark};
  my $translated = $_[0]->{replacements}->{old}->{$oldmark};
  return unless defined $translated;

  # Chase graph of replacements if possible
  return $self->_translate_oldmark($translated);
}

sub _get_last_mark {
  my ($self, $branch) = @_;
  return $_[0]->{branches}->{$branch};
}

sub _update_branch {
  my ($self, $branch, $mark) = @_;
  $_[0]->{branches}->{$branch} = $mark;
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

