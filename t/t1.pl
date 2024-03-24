
#!perl
use 5.006;
use strict;
use warnings;
use Data::Dumper;

use lib './../lib';
use IO::Reverse;

my $file='./' . int(rand(2**20)) . '.txt';

open F, '>', $file or die;

foreach my $i ( 1..10 ) {
	print F "$i\n";
}

close F;

my @v = (10,9,8,7,6,5,4,3,2,1);

open F, '<', $file or die;

my @t=<F>;
chomp @t;

print '@t: ' . Dumper(\@t);
print '@v: ' . Dumper(\@v);

my $isOK=1;

foreach my $i ( @v ) {
	#$isOK=0 unless $i == $t[$i];
	#last if !$isOK;
	#die;
	print "v: $i\n";
	die unless $i == int($t[$i-1]);
}

unlink $file;





