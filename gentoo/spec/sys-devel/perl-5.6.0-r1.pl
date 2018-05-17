#!perl
use strict;
use warnings;

use proto q{gentoo/ebuild};

map_ebuild 'sys-devel/perl/perl-5.6.0-r1.ebuild' => 'sys-devel/perl.ebuild';
add_source_branch 'sys-devel/perl.dir';
