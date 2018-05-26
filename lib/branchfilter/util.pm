use 5.006;    # our
use strict;
use warnings;

package branchfilter::util;

our $VERSION = '0.001000';

# ABSTRACT: things and shit

# AUTHORITY

use Exporter qw();

*import = \&Exporter::import;

our @EXPORT_OK = qw( _lazy_get _lazy_constructor %BLOCK_TYPES );

our %BLOCK_TYPES = (map {$_ => 1} qw(commit tag reset blob checkpoint progress feature option done));

sub _lazy_constructor {
  my ($rules, $class, @args) = @_;
  my $self = bless {}, $class;
  my $args = ref $args[0] ? {%{$args[0]}} : {@args[0 .. $#args]};
  $self->{_init_args} = $args;
  for my $required (@{$rules->{required} || []}) {
    _lazy_get($self, $required);
  }
  for my $optional (@{$rules->{optional} || []}) {
    exists $args->{$optional} and _lazy_get($self, $optional);
  }
  keys %{$args} and die "Unknown constructer argments [ @{[ keys %{$args} ]} ]";
  return $self;
}

sub _lazy_get {
  my ($self, $field) = @_;
  unless (exists $self->{$field}) {
    if (exists $self->{_init_args}->{$field}) {
      my $value = delete $self->{_init_args}->{$field};
      if (my $cb = $self->can("_coerce_${field}")) {
        $value = $self->$cb($value);
      }
      if (my $cb = $self->can("_validate_${field}")) {
        $self->$cb($value);
      }
      if (my $cb = $self->can("_normalize_${field}")) {
        $value = $self->$cb($value);
      }
      $self->{$field} = $value;
      return $value;
    }
    else {
      if (my $cb = $self->can("_default_${field}")) {
        my $value = $self->$cb();
        if (my $vcb = $self->can("_validate_${field}")) {
          $self->$vcb($value);
        }
        if (my $ncb = $self->can("_normalize_${field}")) {
          $value = $self->$ncb($value);
        }
        $self->{$field} = $value;
        return $value;
      }
      die "No default for required field ${field}";
    }
  }
  return $self->{$field};
}

1;

