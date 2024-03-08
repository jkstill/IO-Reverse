
package IO::Reverse;

use warnings;
use strict;
use IO::File;
use Fcntl;
use Data::Dumper;

=head1 NAME

IO::Reverse - read a file in reverse

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

 Read a file from the end of file, line by line

 create a test file from the Command Line

 $  for i in $( seq 1 10 )
 do
   echo "this is $i"
 done > t.txt


Now a small test script

 use IO::Reverse;

 my $f = IO::Reverse->new( 
	 FILENAME => './t.txt'
 );

 while ( my $line = $f->next ) {
	print "$line";
 }


=cut

=head1 METHODS

There are only 2 methods: new() and next();

=head2 new

 my $f = IO::Reverse->new(
    FILENAME => './t.txt'
 );

=head2 next

Iterate through the file

 while ( my $line = $f->next ) {
   print "$line";
 }


=cut


=head1 AUTHOR

Jared Still, C<< <jkstill at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-io-reverse at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=IO-Reverse>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc IO::Reverse


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=IO-Reverse>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/IO-Reverse>

=item * Search CPAN

L<https://metacpan.org/release/IO-Reverse>

=back

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2023 by Jared Still.

This is free software, licensed under: 

  The MIT License

=cut


use Exporter qw(import);
#our @EXPORT = qw();
our @ISA=qw(Exporter);

my $debug=0;

sub new {
	my ($class, $args) = @_;
	my $fh = IO::File->new;

	$fh->open($args->{FILENAME})  || die "Reverse: could not open file: $args->{FILENAME} - $!\n";
	$args->{FH}=$fh;
	$args->{F_SIZE} = -s $args->{FILENAME};
	# offset starts at penultimate character in file

	$args->{DEBUG} ||= 0;
	$debug=$args->{DEBUG};
	$args->{CHUNKSIZE} ||= 1024;
	$args->{F_OFFSET} = $args->{CHUNKSIZE} * -1; # offset continually decrements to allow reverse seek

	if ( $args->{CHUNKSIZE} >= abs($args->{F_SIZE}) ) {
		$args->{CHUNKSIZE} = $args->{F_SIZE} +1; # this +1 should be become the size of the line delimiter (ie. Windows)
		$args->{F_OFFSET} = ($args->{F_SIZE} * -1) +1 ;
	}

	$args->{BOF} ||= 0; # true/false - have we reached beginning of file - control used in loadBuffer()
	$args->{SEND_BOF} = 0; # true/false - have we reached beginning of file - control used in next()

	#die "CHUNKSIZE: $args->{CHUNKSIZE}\n";

	# set to EOF minus offset 
	# offset to avoid the end of line/file characters
	$fh->seek($fh->getpos, SEEK_END);
	$fh->seek($args->{F_OFFSET}, 2);

	$args->{F_POS} =  $fh->getpos;
	$args->{DEBUG} ||= 0;

	my $self = bless $args, $class;
	return $self;
}


# closure to preserve buffer across calls
{

my ($a,@b) = ('',());
my ($firstChar) = ('');
my %readHash = ();

sub setReadParameters {
	my ($self) = @_;

	pdebug("sub setReadParameters()\n",1);

	if ( abs($self->{F_OFFSET}) + $self->{CHUNKSIZE} > $self->{F_SIZE} ) {
		pdebug("setReadParameters(): recalculating chunkSize and offset\n");
		pdebug("before - fsize: $self->{F_SIZE}\n");	
		pdebug("before - chunkSize: $self->{CHUNKSIZE}\n");	
		pdebug("before - offset $self->{F_OFFSET}\n");	
		$self->{CHUNKSIZE} = $self->{F_SIZE} - abs($self->{F_OFFSET}) -1;
		
		$self->{F_OFFSET} = ($self->{F_SIZE} * -1) +1;

		pdebug("after - chunkSize: $self->{CHUNKSIZE}\n");	
		pdebug("after - offset $self->{F_OFFSET}\n");	
		$self->{BOF}=1;
	} else {
		pdebug( "setReadParameters(): setting for CUR\n");
		$self->{F_OFFSET} += ($self->{CHUNKSIZE} * -1);
		pdebug("cur - offset $self->{F_OFFSET}\n");	
	}

	pdebug( "  offset: $self->{F_OFFSET}\n");
	pdebug( "\n");

	if ($debug) {
		my ($package, $filename, $line) = caller;
		pdebug("setReadParameters() returning to $package:$line\n");
	}

	return;
}


sub initReadHash {
	pdebug("initReadHash(): reset read variables\n",1);
	%readHash = (
		READSZ => 0,
		BUF => '',
		LASTCHR => '',
	);

	if ($debug) {
		my ($package, $filename, $line) = caller;
		pdebug("initReadHash() returning to $package:$line\n");
	}
}

sub dataRead {
	my ($self) = @_;

	pdebug("sub dataRead()\n", 1);

	pdebug("dataRead(): calling initReadHash()\n",1,'-');
	initReadHash();

	#print Dumper(\%readHash);

	# read until BOF or newline found in BUF
	my $buffer='';
	my $iter=0;
	#until ( $self->{BOF} or $buffer =~ /\n/ ) {
	while(1) {
		pdebug("dataRead() - iter: " . $iter++  . "\n");
		$readHash{READSZ} = read($self->{FH}, $buffer, $self->{CHUNKSIZE} );	
		pdebug("dataRead() - READSZ: $readHash{READSZ}\n");
		pdebug("dataRead() - buffer:  $buffer\n");
		last if $readHash{READSZ} < 1;
		$readHash{BUF} = $buffer . $readHash{BUF};
		$readHash{LASTCHR} = substr($readHash{BUF},-1,1) if $readHash{BUF};
		pdebug("dataRead() - calling setReadParameters()\n",1,'-');
		$self->setReadParameters();
		last if $self->{BOF} or $buffer =~ /\n/ ;
		pdebug("dataRead() - BUF: $readHash{BUF}|\n");
	}

	pdebug("dataRead() final - BUF: $readHash{BUF}|\n");

	pdebug(" READSZ: $readHash{READSZ}\n");
	pdebug("    BUF: " . substr($readHash{BUF},0,80) . "\n");
	pdebug("LASTCHR: ord(LASTCHR) " . ord($readHash{LASTCHR}) . " - $readHash{LASTCHR}\n");

	if ($debug) {
		my ($package, $filename, $line) = caller;
		pdebug("dataRead() returning to $package:$line\n");
	}

	return;
}

sub loadBuffer {
	my ($self) = @_;

	pdebug("sub loadBuffer()\n",1);

	pdebug("chunkSize: $self->{CHUNKSIZE}\n");
	pdebug("loadBuffer() - calling dataRead()\n",1,'-');
	$self->dataRead();

	pdebug("buffer: |$readHash{BUF}|\n");
	$readHash{LASTCHR} = substr($readHash{BUF},-1,1); 
	pdebug("loadBuffer(): \$readHash{LASTCHR} ascii val: " . ord($readHash{LASTCHR}) . " - $readHash{LASTCHR}\n");
	chomp $readHash{BUF};
	#print "buffer: |$readHash{BUF}|\n";

	return undef unless $readHash{READSZ};
	$firstChar = substr($readHash{BUF},0,1);
	if ($firstChar eq "\n") {
		pdebug("loadBuffer(): \$firstChar is newline\n");
		$readHash{BUF} = substr($readHash{BUF},1);
	}	

	pdebug( "   fsize: $self->{F_SIZE}\n");
	pdebug( "  offset: $self->{F_OFFSET}\n");

	@b = split(/\n/,$readHash{BUF});

	if ($debug) {
		print 'loadBuffer(): @b: ' . Dumper(\@b);
		print 'loadBuffer(): $a: ' . "$a|\n";
	}

	pdebug("loadBuffer(): \$a: $a\n");

	if ($a)  {
		if ( $readHash{LASTCHR} eq "\n" ) {
			pdebug("loadBuffer(): push \$a -> \@b\n");
			push @b, $a;
		} else {
			pdebug("loadBuffer(): append \$a to last element of \@b\n");
			$b[$#b] .= $a;
		}
		$a = '';
	}

	# this code must have a local loop (or something like it)  to get a complete line
	# when the line is larger than 2x chunksize
	# if chunksize is large enough, the loop will rarely be necessary
	if (! $self->{BOF} and $firstChar ne "\n" ) {
		#($a) = shift(@b);
		$a = shift(@b);
		#print "a: $a\n";
		pdebug("\nsetting \$a: $a\n");
		print 'loadBuffer(): @b: ' . Dumper(\@b) if $debug;
	} else {
		pdebug("\nre-setting \$a\n");
		$a = '';
	};

	$self->setReadParameters();

	pdebug( '=' x 80 . "\n");

	$self->{FH}->seek($self->{F_OFFSET}, 2);
	
	if ($debug) {
		my ($package, $filename, $line) = caller;
		pdebug("loadBuffer() returning to $package:$line\n");
	}

}

sub next {
	my ($self) = @_;

	pdebug("sub next()\n",1);

	return undef if $self->{SEND_BOF};

	# if there is no data loaded by loadBuffer(), we are done
	if (! @b ) {
		pdebug("Calling loadBuffer()\n",1,'-');
		if (! $self->loadBuffer() ) {
			$self->{SEND_BOF}=1;
			if ($a) {
				pdebug("next() - done: returning \$a: $a\n");
				return "$a\n";	
			} else {
				pdebug("next() - done: returning undef\n");
				return undef;
			}
		}
	}

	if (@b) {
		my $r = pop @b;
		pdebug("popping data from \@b \$r: $r\n");
		$r = "r: $r" if $debug;
		return "$r\n";
	} else {
		if ($a) {
			my $r = $a;
			$r = "a: $r" if $debug;
			pdebug("next() - continue: returning \$a: $a\n");
			return "$r\n";
		} else {
			pdebug("next() - continue: returning undef\n");
			return undef;
		}
	}


}

} # end of closure


sub pdebug {
	my ($s,$useBanner,$bannerChar) = @_;
	return unless $debug;
	$bannerChar ||= '=';

	$useBanner ||= 0;

	my $bannerString = $bannerChar x 40;
	if ($useBanner) {
		print "\n";
		print "$bannerString\n$bannerChar$bannerChar ";
	}
	print "$s";
	if ($useBanner) {
		print "$bannerString\n";
		print "\n";
	}
	return;
}

1;


