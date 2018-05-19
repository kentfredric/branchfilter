
use strict;
use warnings;

use Test::More;
use branchfilter;

my @ebuilds = (qw(
    sys-devel/perl/perl-5.6.0-r1.ebuild
    sys-devel/perl/perl-5.6.0-r2.ebuild
    sys-devel/perl/perl-5.6.0-r3.ebuild
    sys-devel/perl/perl-5.6.0-r4.ebuild
    sys-devel/perl/perl-5.6.0-r5.ebuild
    sys-devel/perl/perl-5.6.0-r6.ebuild
    sys-devel/perl/perl-5.6.1.ebuild
    sys-devel/perl/perl-5.6.1-r10.ebuild
    sys-devel/perl/perl-5.6.1-r11.ebuild
    sys-devel/perl/perl-5.6.1-r1.ebuild
    sys-devel/perl/perl-5.6.1-r2.ebuild
    sys-devel/perl/perl-5.6.1-r3.ebuild
    sys-devel/perl/perl-5.6.1-r4.ebuild
    sys-devel/perl/perl-5.6.1-r5.ebuild
    sys-devel/perl/perl-5.6.1-r6.ebuild
    sys-devel/perl/perl-5.6.1-r7.ebuild
    sys-devel/perl/perl-5.6.1-r8.ebuild
    sys-devel/perl/perl-5.6.1-r9.ebuild
    sys-devel/perl/perl-5.8.0.ebuild
    sys-devel/perl/perl-5.8.0-r10.ebuild
    sys-devel/perl/perl-5.8.0-r1.ebuild
    sys-devel/perl/perl-5.8.0-r2.ebuild
    sys-devel/perl/perl-5.8.0-r3.ebuild
    sys-devel/perl/perl-5.8.0-r4.ebuild
    sys-devel/perl/perl-5.8.0-r5.ebuild
    sys-devel/perl/perl-5.8.0-r6.ebuild
    sys-devel/perl/perl-5.8.0-r7.ebuild
    sys-devel/perl/perl-5.8.0-r8.ebuild
    sys-devel/perl/perl-5.8.0-r9.ebuild
));

for my $ebuild (@ebuilds) {
  my ($atom) = $ebuild;
  $atom =~ s{/[^/]+/}{/};
  $atom =~ s{\.ebuild\z}{};
  my ($dest_filename) = $ebuild;
  $dest_filename =~ s{/[^/]+\z}{.ebuild};

  my $need_nl    = 0;
  my $last_stats = 0;

  my $bf = branchfilter->new(
    source_repo => '/tmp/ghist-2015',
    prune_empty => 1,
    write       => !!$ENV{DO_WRITE},
    handlers    => {
      commit => sub {
        my ($self, $block, $info) = @_;
        $info->{branch} = 'refs/heads/' . $atom;
        $info->{changes} = [grep {$_->[1] eq $ebuild} @{$info->{changes}}];
        if (@{$info->{changes}}) {
          $block->{data} = $atom . ': ' . $block->{data};
          my ($message,) = split qq/\n/, $block->{data};
          $message = substr $message, 0, 90;

          if ($need_nl) {
            *STDERR->print("\n");
            $need_nl = 0;
          }

          # note explain $info->{author};
          *STDERR->printf("\e[32m%s\e[0m - \e[33m%s\e[0m: %s\n",
                          $info->{author}->{email},
                          scalar localtime($info->{author}->{'time'}), $message);
          for my $change (@{$info->{changes}}) {
            my ($source_file) = $change->[1] || '';
            *STDERR->printf("    \e[34m%s\e[0m \e[35m%s\e[0m -> \e[36m%s\e[0m\n",
                            $change->[0], $source_file, $dest_filename);
            $change->[1] = $dest_filename;
            $change->[2]->{raw} =~ s{\Q${source_file}\E\z}{$dest_filename};
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
}
done_testing;

