#!/usr/bin/env perl
#
use warnings;
use strict;

use IO::File;
use Fcntl;
use Data::Dumper;

use v5.10.1;

my $fh = IO::File->new;

my $file=$ARGV[0];
my @lines=();

$fh->open($file) or die "could not open file: '$file' - $!\n";

my $fsize = -s $file;
$fsize += 1;
#print "fsize: $fsize\n";

my $chunkSize=1024;
my $offset = $chunkSize * -1;
#print "offset: $offset\n";
if ($chunkSize >= abs($fsize) ) {
	$chunkSize = $fsize + 1;
	$offset = ($fsize * -1) +1 ;
}

#print "offset: $offset\n";
#print "chunkSize $chunkSize\n";

$fh->seek($fh->getpos, SEEK_END);
$fh->seek($offset, 2);

my $debug=0;
my $BOF=0;

my ($a,@b) = ('',());
my ($firstChar,$lastChar) = ('','');

#while (<$fh>) {
while (1) {
	my $buffer='';

	my $readSize = read($fh, $buffer, $chunkSize );	
	pdebug("readSize: $readSize\n");
	$lastChar = substr($buffer,-1,1);
	chomp $buffer;
	#print "buffer: |$buffer|\n";

	last unless $readSize;
	$firstChar = substr($buffer,0,1);
	if ($firstChar eq "\n") {
		$buffer = substr($buffer,1);
	}	

	#print "\nbuffer: |$buffer|\n";

	pdebug( "   fsize: $fsize\n");
	pdebug( "  offset: $offset\n");

	@b = split(/\n/,$buffer);

	pdebug("\$a: $a\n");

	if ($a)  {
		pdebug("\n1\n");
		if ( $lastChar eq "\n" ) {
			push @b, $a;
		} else {
			$b[$#b] .= $a;
		}
		$a = '';
	}

	if (! $BOF and $firstChar ne "\n" ) {
		pdebug("\n2\n");
		($a) = shift(@b);
	} else {
		pdebug("\n3\n");
		$a = '';
	};

	#print '@b: ' . Dumper(\@b);

	if ( abs($offset)  + $chunkSize > $fsize ) {
		pdebug( "setting for BOF\n");
		#$chunkSize = (abs($offset)  + $chunkSize ) - $fsize;
		$chunkSize = $fsize - abs($offset) -1;
		$offset = (($fsize+0) * -1) + 1;
		pdebug("  chunkSize: $chunkSize\n");
		$BOF=1;
	} else {
		pdebug( "setting for CUR\n");
		$offset += ($chunkSize * -1);
	}

	pdebug( "  offset: $offset\n");
	pdebug( "\n");

	#print "b:\n" .  join("\n",@b) . "\n";
	#print 'b: ' . Dumper(\@b);
	print join("\n",reverse @b)."\n";

	#last if $BOF;

	#pdebug( '=' x 80 . "\n");
	pdebug( '=' x 80 . "\n");

	#last if abs($offset) >= $fsize;

	$fh->seek($offset, 2);
	
}

print "$a\n" if $a;
#print "\n";

sub pdebug {
	my ($s) = @_;
	return unless $debug;
	print "$s";
	return;
}


