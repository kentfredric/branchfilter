
use strict;
use warnings;

use Test::More;
use branchfilter;

my $need_nl    = 0;
my $last_stats = 0;

my $bf = branchfilter->new(
  source_repo => '/tmp/ghist-2015',
  prune_empty => 1,
  write       => !!$ENV{DO_WRITE},
  handlers    => {
    commit => sub {
      my ($self, $block, $info) = @_;
      $info->{branch} = 'refs/heads/test';
      $info->{changes} = [
        grep {
                $_->[1] =~ m{\A(dev-lang|sys-devel)/perl}
            and $_->[1] !~ m{/ChangeLog\z}
            and $_->[1] !~ m{/Manifest\z}
            and $_->[1] !~ m{\.frozen\z}
            and $_->[1] !~ m{perl/files/digest-perl-5}
        } @{$info->{changes}}];
      if (@{$info->{changes}}) {
        my ($message,) = split qq/\n/, $block->{data};
        $message = substr $message, 0, 30;

        if ($need_nl) {
          *STDERR->print("\n");
          $need_nl = 0;
        }

        # note explain $info->{author};
        *STDERR->printf("\e[32m%s\e[0m - \e[33m%s\e[0m: %s\n",
                        $info->{author}->{email},
                        scalar localtime($info->{author}->{'time'}), $message);
        for my $change (@{$info->{changes}}) {
          *STDERR->printf("    \e[34m%s\e[0m \e[35m%s\e[0m\n", $change->[0], $change->[1] || '');
        }
      }
    },
    progress => sub {
      my $stats = $_[0]->stats;
      if ($need_nl) {
        *STDERR->print("\r");
      }
      *STDERR->printf("\e[31m%s\e[0m", $stats);
      $need_nl = 1;
      $_[2]->{skip} = 1;
    }
  });

while ($bf->next_block) { }

done_testing;

