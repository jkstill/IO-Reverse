
package IO::Reverse;

use warnings;
use strict;
use IO::File;
use Fcntl;
use Data::Dumper;
use lib './lib';  # local Verbose.pm
use Verbose;

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

	$args->{verbose} = Verbose->new(
		{
			VERBOSITY=>$args->{VERBOSITY},
			LABELS=>1,
			TIMESTAMP=>0,
			HANDLE=>*STDERR
		} 
	);



	$args->{DEBUG} ||= 0;
	#$debug=$args->{DEBUG};
	$debug=0;
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

	$self->{verbose}->print(1,"sub setReadParameters()",[]);

	if ( abs($self->{F_OFFSET}) + $self->{CHUNKSIZE} > $self->{F_SIZE} ) {

		$self->{verbose}->print(2,"setReadParameters(): recalculating chunkSize and offset",[]);
		$self->{verbose}->print(3,"before - fsize: $self->{F_SIZE}",[]);	
		$self->{verbose}->print(3,"before - chunkSize: $self->{CHUNKSIZE}",[]);	
		$self->{verbose}->print(3,"before - offset $self->{F_OFFSET}",[]);	

		$self->{CHUNKSIZE} = $self->{F_SIZE} - abs($self->{F_OFFSET}) -1;
		
		$self->{F_OFFSET} = ($self->{F_SIZE} * -1) +1;

		$self->{verbose}->print(3,"after - chunkSize: $self->{CHUNKSIZE}",[]);	
		$self->{verbose}->print(3,"after - offset $self->{F_OFFSET}",[]);	
		
		$self->{BOF}=1;
	} else {
		$self->{verbose}->print(2, "setReadParameters(): setting for CUR",[]);
		$self->{F_OFFSET} += ($self->{CHUNKSIZE} * -1);
		$self->{verbose}->print(3,"cur - offset $self->{F_OFFSET}",[]);	
	}

	$self->{verbose}->print(2, "  offset: $self->{F_OFFSET}\n",[]);

	if ($self->{VERBOSITY}) {
		my ($package, $filename, $line) = caller;
		$self->{verbose}->print(3,"setReadParameters() returning to $package:$line",[]);
	}

	return;
}


sub initReadHash {
	my ($self) = @_;
	$self->{verbose}->print(2,"initReadHash(): reset read variables",[]);
	%readHash = (
		READSZ => 0,
		BUF => '',
		LASTCHR => '',
	);

	if ($self->{VERBOSITY}) {
		my ($package, $filename, $line) = caller;
		$self->{verbose}->print(3,"initReadHash() returning to $package:$line",[]);
	}
}

sub dataRead {
	my ($self) = @_;

	$self->{verbose}->print(2,"sub dataRead()", []);

	$self->{verbose}->print(2,"dataRead(): calling initReadHash()",[]);
	$self->initReadHash();

	#print Dumper(\%readHash);

	# read until BOF or newline found in BUF
	my $buffer='';
	my $iter=0;
	#until ( $self->{BOF} or $buffer =~ /\n/ ) {
	while(1) {
		$self->{verbose}->print(3,"dataRead() - iter: " . $iter++ ,[]);
		$readHash{READSZ} = read($self->{FH}, $buffer, $self->{CHUNKSIZE} );	
		$self->{verbose}->print(3,"dataRead() - READSZ: $readHash{READSZ}",[]);
		$self->{verbose}->print(3,"dataRead() - buffer:  $buffer",[]);
		last if $readHash{READSZ} < 1;
		$readHash{BUF} = $buffer . $readHash{BUF};
		$readHash{LASTCHR} = substr($readHash{BUF},-1,1) if $readHash{BUF};
		$self->{verbose}->print(3,"dataRead() - calling setReadParameters()",[]);
		$self->setReadParameters();
		last if $self->{BOF} or $buffer =~ /\n/ ;
		$self->{verbose}->print(3,"dataRead() - BUF: $readHash{BUF}|",[]);
	}

	$self->{verbose}->print(3,"dataRead() final - BUF: $readHash{BUF}|",[]);

	$self->{verbose}->print(3," READSZ: $readHash{READSZ}",[]);
	$self->{verbose}->print(3,"    BUF: " . substr($readHash{BUF},0,80), []);
	$self->{verbose}->print(3,"LASTCHR: ord(LASTCHR) " . ord($readHash{LASTCHR}) . " - $readHash{LASTCHR}" , []);

	if ($self->{VERBOSITY}) {
		my ($package, $filename, $line) = caller;
		$self->{verbose}->print(3,"dataRead() returning to $package:$line",[]);
	}

	return;
}

sub loadBuffer {
	my ($self) = @_;

	$self->{verbose}->print(1,"sub loadBuffer()",[]);

	$self->{verbose}->print(2,"chunkSize: $self->{CHUNKSIZE}",[]);
	$self->{verbose}->print(2,"loadBuffer() - calling dataRead()",[]);
	$self->dataRead();

	$self->{verbose}->print(2,"buffer: |$readHash{BUF}|",[]);
	$readHash{LASTCHR} = substr($readHash{BUF},-1,1); 
	$self->{verbose}->print(2,"loadBuffer(): \$readHash{LASTCHR} ascii val: " . ord($readHash{LASTCHR}) . " - $readHash{LASTCHR}",[]);
	chomp $readHash{BUF};
	#print "buffer: |$readHash{BUF}|\n";

	return undef unless $readHash{READSZ};
	$firstChar = substr($readHash{BUF},0,1);
	if ($firstChar eq "\n") {
		$self->{verbose}->print(2,"loadBuffer(): \$firstChar is newline",[]);
		$readHash{BUF} = substr($readHash{BUF},1);
	}	

	$self->{verbose}->print(2, "   fsize: $self->{F_SIZE}",[]);
	$self->{verbose}->print(2, "  offset: $self->{F_OFFSET}",[]);

	@b = split(/\n/,$readHash{BUF});

	$self->{verbose}->print(2, 'loadBuffer(): @b: ', \@b);
	$self->{verbose}->print(2, 'loadBuffer(): $a: ' . "$a|",[]);


	if ($a)  {
		if ( $readHash{LASTCHR} eq "\n" ) {
			$self->{verbose}->print(3,"loadBuffer(): push \$a -> \@b",[]);
			push @b, $a;
		} else {
			$self->{verbose}->print(3,"loadBuffer(): append \$a to last element of \@b",[]);
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
		$self->{verbose}->print(3,"setting \$a: $a",[]);
		print 'loadBuffer(): @b: ' . Dumper(\@b) if $debug;
	} else {
		$self->{verbose}->print(3,"re-setting \$a",[]);
		$a = '';
	};

	$self->setReadParameters();

	$self->{verbose}->print(1, '=' x 80,[]);

	$self->{FH}->seek($self->{F_OFFSET}, 2);
	
	if ($debug) {
		my ($package, $filename, $line) = caller;
		$self->{verbose}->print(2,"loadBuffer() returning to $package:$line",[]);
	}

}

sub next {
	my ($self) = @_;

	$self->{verbose}->print(1,"sub next()",[]);

	return undef if $self->{SEND_BOF};

	# if there is no data loaded by loadBuffer(), we are done
	if (! @b ) {
		$self->{verbose}->print(2,"Calling loadBuffer()\n",[]);
		if (! $self->loadBuffer() ) {
			$self->{SEND_BOF}=1;
			if ($a) {
				$self->{verbose}->print(3,"next() - done: returning \$a: $a",[]);
				return "$a\n";	
			} else {
				$self->{verbose}->print(3,"next() - done: returning undef",[]);
				return undef;
			}
		}
	}

	if (@b) {
		my $r = pop @b;
		$self->{verbose}->print(2,"popping data from \@b \$r: $r",[]);
		$r = "r: $r" if $debug;
		return "$r\n";
	} else {
		if ($a) {
			my $r = $a;
			$r = "a: $r" if $debug;
			$self->{verbose}->print(3,"next() - continue: returning \$a: $a",[]);
			return "$r\n";
		} else {
			$self->{verbose}->print(3,"next() - continue: returning undef",[]);
			return undef;
		}
	}


}

} # end of closure


1;


