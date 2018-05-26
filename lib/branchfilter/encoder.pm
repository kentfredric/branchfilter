use 5.006;    # our
use strict;
use warnings;

package branchfilter::encoder;

our $VERSION = '0.001000';

# ABSTRACT: Wrap shit

# AUTHORITY

use branchfilter::util qw/ _lazy_get _lazy_constructor %BLOCK_TYPES /;

sub new {_lazy_constructor({optional => [qw( marks namespace prune_empty )]}, @_)}
sub marks       {_lazy_get($_[0], 'marks')}
sub namespace   {_lazy_get($_[0], 'namespace')}
sub stats       {_lazy_get($_[0], 'stats')}
sub prune_empty {_lazy_get($_[0], 'prune_empty')}

sub _default_marks {require branchfilter::marks; branchfilter::marks->new()}
sub _default_namespace   {'main'}
sub _default_prune_empty {1}

sub _default_stats {
  +{map {$_ => 0} keys %BLOCK_TYPES};
}

sub encode_block {
  my ($self, $block, $info) = @_;
  if ($info->{skip}) {
    $info->{mark}
      and (exists $self->{marks} ? $self->{marks} : $self->marks)
      ->set_mark_skip((exists $self->{namespace} ? $self->{namespace} : $self->namespace), $info->{mark});
    return;
  }
  my $cb = $_[0]->can('encode_' . $block->{type});
  $cb and $self->$cb($block, $info);
  $info->{skip} and return;
  $self->stats->{$block->{type}}++;
}

sub encode_commit {
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
    $self->marks->set_mark_skip($self->namespace, $info->{mark}) if exists $info->{mark};
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
      and $block->{from} = [sprintf 'from %s', $self->marks->get_newmark($self->namespace, $info->{from})];
    delete $block->{mark}; exists $info->{mark}
      and $block->{mark} = [sprintf 'mark %s', $self->marks->get_newmark($self->namespace, $info->{mark})];
    delete $block->{merge}; exists $info->{merge}
      and $block->{merge} = [sprintf 'merge %s', $self->marks->get_newmark($self->namespace, $info->{mark})];
  }
}

1;

