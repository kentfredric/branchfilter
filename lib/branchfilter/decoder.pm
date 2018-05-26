use 5.006;    # our
use strict;
use warnings;

package branchfilter::decoder;

our $VERSION = '0.001000';

# ABSTRACT: input wrapping to userspace

# AUTHORITY

use branchfilter::util qw/ _lazy_get _lazy_constructor %BLOCK_TYPES /;

sub new {_lazy_constructor({}, @_)}
sub stats {_lazy_get($_[0], 'stats')}

sub _default_stats {
  +{map {$_ => 0} keys %BLOCK_TYPES};
}

sub decode_block {
  my ($self, $block, $info) = @_;
  $self->stats->{$block->{type}}++;
  my $cb = $self->can('decode_' . $block->{type});
  $cb and $self->$cb($block, $info);
}

sub decode_commit {
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

1;

