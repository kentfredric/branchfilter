
use strict;
use warnings;

use Test::More;
use Time::HiRes qw( gettimeofday tv_interval );
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
    dev-lang/perl/perl-5.10.1.ebuild
    dev-lang/perl/perl-5.12.1.ebuild
    dev-lang/perl/perl-5.12.1-r1.ebuild
    dev-lang/perl/perl-5.12.1-r2.ebuild
    dev-lang/perl/perl-5.12.2.ebuild
    dev-lang/perl/perl-5.12.2-r1.ebuild
    dev-lang/perl/perl-5.12.2-r2.ebuild
    dev-lang/perl/perl-5.12.2-r3.ebuild
    dev-lang/perl/perl-5.12.2-r4.ebuild
    dev-lang/perl/perl-5.12.2-r5.ebuild
    dev-lang/perl/perl-5.12.2-r6.ebuild
    dev-lang/perl/perl-5.12.3.ebuild
    dev-lang/perl/perl-5.12.3-r1.ebuild
    dev-lang/perl/perl-5.12.4.ebuild
    dev-lang/perl/perl-5.12.4-r1.ebuild
    dev-lang/perl/perl-5.12.4-r2.ebuild
    dev-lang/perl/perl-5.12.5.ebuild
    dev-lang/perl/perl-5.14.1.ebuild
    dev-lang/perl/perl-5.14.1-r1.ebuild
    dev-lang/perl/perl-5.14.2.ebuild
    dev-lang/perl/perl-5.16.0.ebuild
    dev-lang/perl/perl-5.16.1.ebuild
    dev-lang/perl/perl-5.16.2.ebuild
    dev-lang/perl/perl-5.16.2-r1.ebuild
    dev-lang/perl/perl-5.16.3.ebuild
    dev-lang/perl/perl-5.18.1.ebuild
    dev-lang/perl/perl-5.18.2.ebuild
    dev-lang/perl/perl-5.18.2-r1.ebuild
    dev-lang/perl/perl-5.18.2-r2.ebuild
    dev-lang/perl/perl-5.20.0.ebuild
    dev-lang/perl/perl-5.20.0-r1.ebuild
    dev-lang/perl/perl-5.20.0-r2.ebuild
    dev-lang/perl/perl-5.20.1.ebuild
    dev-lang/perl/perl-5.20.1-r1.ebuild
    dev-lang/perl/perl-5.20.1-r2.ebuild
    dev-lang/perl/perl-5.20.1-r3.ebuild
    dev-lang/perl/perl-5.20.1-r4.ebuild
    dev-lang/perl/perl-5.20.2.ebuild
    dev-lang/perl/perl-5.20.2-r1.ebuild
    dev-lang/perl/perl-5.22.0.ebuild
    dev-lang/perl/perl-5.6.1-r10.ebuild
    dev-lang/perl/perl-5.6.1-r11.ebuild
    dev-lang/perl/perl-5.6.1-r12.ebuild
    dev-lang/perl/perl-5.8.0-r10.ebuild
    dev-lang/perl/perl-5.8.0-r11.ebuild
    dev-lang/perl/perl-5.8.0-r12.ebuild
    dev-lang/perl/perl-5.8.0-r9.ebuild
    dev-lang/perl/perl-5.8.1.ebuild
    dev-lang/perl/perl-5.8.1-r1.ebuild
    dev-lang/perl/perl-5.8.1-r2.ebuild
    dev-lang/perl/perl-5.8.1_rc1.ebuild
    dev-lang/perl/perl-5.8.1_rc2.ebuild
    dev-lang/perl/perl-5.8.1_rc3.ebuild
    dev-lang/perl/perl-5.8.1_rc4.ebuild
    dev-lang/perl/perl-5.8.2.ebuild
    dev-lang/perl/perl-5.8.2-r1.ebuild
    dev-lang/perl/perl-5.8.2-r2.ebuild
    dev-lang/perl/perl-5.8.2-r3.ebuild
    dev-lang/perl/perl-5.8.2-r4.ebuild
    dev-lang/perl/perl-5.8.3.ebuild
    dev-lang/perl/perl-5.8.4.ebuild
    dev-lang/perl/perl-5.8.4-r1.ebuild
    dev-lang/perl/perl-5.8.4-r2.ebuild
    dev-lang/perl/perl-5.8.4-r3.ebuild
    dev-lang/perl/perl-5.8.4-r4.ebuild
    dev-lang/perl/perl-5.8.5.ebuild
    dev-lang/perl/perl-5.8.5-r1.ebuild
    dev-lang/perl/perl-5.8.5-r2.ebuild
    dev-lang/perl/perl-5.8.5-r3.ebuild
    dev-lang/perl/perl-5.8.5-r4.ebuild
    dev-lang/perl/perl-5.8.5-r5.ebuild
    dev-lang/perl/perl-5.8.6.ebuild
    dev-lang/perl/perl-5.8.6-r1.ebuild
    dev-lang/perl/perl-5.8.6-r2.ebuild
    dev-lang/perl/perl-5.8.6-r3.ebuild
    dev-lang/perl/perl-5.8.6-r4.ebuild
    dev-lang/perl/perl-5.8.6-r5.ebuild
    dev-lang/perl/perl-5.8.6-r6.ebuild
    dev-lang/perl/perl-5.8.6-r7.ebuild
    dev-lang/perl/perl-5.8.6-r8.ebuild
    dev-lang/perl/perl-5.8.7.ebuild
    dev-lang/perl/perl-5.8.7-r1.ebuild
    dev-lang/perl/perl-5.8.7-r2.ebuild
    dev-lang/perl/perl-5.8.7-r3.ebuild
    dev-lang/perl/perl-5.8.8.ebuild
    dev-lang/perl/perl-5.8.8-r1.ebuild
    dev-lang/perl/perl-5.8.8-r2.ebuild
    dev-lang/perl/perl-5.8.8-r3.ebuild
    dev-lang/perl/perl-5.8.8-r4.ebuild
    dev-lang/perl/perl-5.8.8-r5.ebuild
    dev-lang/perl/perl-5.8.8-r6.ebuild
    dev-lang/perl/perl-5.8.8-r7.ebuild
    dev-lang/perl/perl-5.8.8-r8.ebuild
    dev-lang/perl/perl-5.8.8_rc1.ebuild
    sys-devel/libperl/libperl-5.10.1.ebuild
    sys-devel/libperl/libperl-5.10.1-r1.ebuild
    sys-devel/libperl/libperl-5.8.0.ebuild
    sys-devel/libperl/libperl-5.8.1.ebuild
    sys-devel/libperl/libperl-5.8.1_rc1.ebuild
    sys-devel/libperl/libperl-5.8.1_rc2.ebuild
    sys-devel/libperl/libperl-5.8.2.ebuild
    sys-devel/libperl/libperl-5.8.2-r1.ebuild
    sys-devel/libperl/libperl-5.8.3.ebuild
    sys-devel/libperl/libperl-5.8.4.ebuild
    sys-devel/libperl/libperl-5.8.4-r1.ebuild
    sys-devel/libperl/libperl-5.8.5.ebuild
    sys-devel/libperl/libperl-5.8.5-r1.ebuild
    sys-devel/libperl/libperl-5.8.6.ebuild
    sys-devel/libperl/libperl-5.8.6-r1.ebuild
    sys-devel/libperl/libperl-5.8.7.ebuild
    sys-devel/libperl/libperl-5.8.8.ebuild
    sys-devel/libperl/libperl-5.8.8-r1.ebuild
    sys-devel/libperl/libperl-5.8.8-r2.ebuild
    sys-devel/libperl/libperl-5.8.8_rc1.ebuild
));

#splice @ebuilds, 4;

my $bf      = branchfilter->new(source_repo => '/tmp/ghist-2015', branches => ['refs/remotes/origin/master']);
my $need_nl = 0;
my $all_out = 0;

my $start                 = [gettimeofday];
my $last                  = $start;
my $last_commit_count     = 0;
my $last_commit_out_count = 0;

for my $ebuild (@ebuilds) {
  my ($atom) = $ebuild;
  $atom =~ s{/[^/]+/}{/};
  $atom =~ s{\.ebuild\z}{};
  my ($dest_filename) = $ebuild;
  $dest_filename =~ s{/[^/]+\z}{.ebuild};

  my $last_stats = 0;

  $bf->_add_handler({
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

         # if ($need_nl) {
         #            *STDERR->print("\n");
         #  $need_nl = 0;
         #}

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
       else {
         $info->{skip} = 1;
       }
     },
     progress => sub {

       my $commits_encoded = $_[0]->encoder->stats->{commit};
       my $commits_decoded = $bf->decoder->stats->{commit};

       $all_out += $commits_encoded;

       if ($ebuild eq $ebuilds[-1]) {
         my $now = [gettimeofday];

         my ($all_interval) = tv_interval($start, $now);
         my ($last_interval) = tv_interval($last, $now); $last = [@{$now}];

         my ($ci_ps)      = $commits_decoded / $all_interval;
         my ($ci_this_ps) = ($commits_decoded - $last_commit_count) / $last_interval;

         my ($co_ps)      = $all_out / $all_interval;
         my ($co_this_ps) = ($all_out - $last_commit_out_count) / $last_interval;

         $last_commit_count     = $commits_decoded;
         $last_commit_out_count = $all_out;

         *STDERR->printf(
             "\e[31mcommits\e[0m in: %10d (%8.3f / %8.3f) out: %10d (%8.3f / %8.3f) (elapsed: %8.3f, interval: %8.3f\n",
             $_[0]->{stats}->{in}->{commit},
             $ci_ps, $ci_this_ps, $all_out, $co_ps, $co_this_ps, $all_interval, $last_interval);
         $all_out = 0;
       }

       # $need_nl = 1;
       $_[2]->{skip} = 1;

     }
   }});
}
while ($bf->next_block) {
}

done_testing;

