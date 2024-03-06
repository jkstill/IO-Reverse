
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
my ($firstChar,$lastChar) = ('','');

sub loadBuffer {
	my ($self) = @_;

	pdebug("loadBuffer()\n",1);

	my $buffer='';

	#print Dumper($self);
	#exit;

	pdebug("chunkSize $self->{CHUNKSIZE}\n");
	my $readSize = read($self->{FH}, $buffer, $self->{CHUNKSIZE} );	
	pdebug("readSize: $readSize\n");
	pdebug("buffer: $buffer\n");
	$lastChar = substr($buffer,-1,1); 
	pdebug("loadBuffer(): \$lastChar: ascii val: " . ord($lastChar) . " - $lastChar\n");
	chomp $buffer;
	#print "buffer: |$buffer|\n";

	return undef unless $readSize;
	$firstChar = substr($buffer,0,1);
	if ($firstChar eq "\n") {
		pdebug("loadBuffer(): \$firstChar is newline\n");
		$buffer = substr($buffer,1);
	}	

	pdebug( "   fsize: $self->{F_SIZE}\n");
	pdebug( "  offset: $self->{F_OFFSET}\n");

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

	if (! $self->{BOF} and $firstChar ne "\n" ) {
		($a) = shift(@b);
		pdebug("\nsetting \$a: $a\n");
	} else {
		pdebug("\n3\n");
		$a = '';
	};

	#print '@b: ' . Dumper(\@b);
	if ( abs($self->{F_OFFSET}) + $self->{CHUNKSIZE} > $self->{F_SIZE} ) {
		pdebug("new(): recalculating chunkSize and offset\n");
		pdebug("before - fsize: $self->{F_SIZE}\n");	
		pdebug("before - chunkSize: $self->{CHUNKSIZE}\n");	
		pdebug("before - offset $self->{F_OFFSET}\n");	
		$self->{CHUNKSIZE} = $self->{F_SIZE} - abs($self->{F_OFFSET}) -1;
		
		$self->{F_OFFSET} = ($self->{F_SIZE} * -1) +1;

		pdebug("after - chunkSize: $self->{CHUNKSIZE}\n");	
		pdebug("after - offset $self->{F_OFFSET}\n");	
		$self->{BOF}=1;
	} else {
		pdebug( "new(): setting for CUR\n");
		$self->{F_OFFSET} += ($self->{CHUNKSIZE} * -1);
		pdebug("cur - offset $self->{F_OFFSET}\n");	
	}

	pdebug( "  offset: $self->{F_OFFSET}\n");
	pdebug( "\n");

	#print "b:\n" .  join("\n",@b) . "\n";
	#print 'b: ' . Dumper(\@b);
	#print join("\n",reverse @b)."\n";

	#last if $self->{BOF};

	#pdebug( '=' x 80 . "\n");
	pdebug( '=' x 80 . "\n");

	$self->{FH}->seek($self->{F_OFFSET}, 2);
	
}

sub next {
	my ($self) = @_;

	return undef if $self->{SEND_BOF};

	if (! @b ) {
		pdebug("Calling loadBuffer()\n",1);
		if (! $self->loadBuffer() ) {
			$self->{SEND_BOF}=1;
			if ($a) {
				return "$a\n";	
			} else {
				return undef;
			}
		}
	}

	if (@b) {
		pdebug("popping data from \@b\n");
		my $r = pop @b;
		$r = "r: $r" if $debug;
		return "$r\n";
	} else {
		if ($a) {
			my $r = $a;
			$r = "a: $r" if $debug;
			#$a='';
			return "$r\n";
		} else {
			return undef;
		}
	}

	#return undef if $self->{BOF};



}

} # end of closure


sub pdebug {
	my ($s,$useBanner) = @_;
	return unless $debug;
	$useBanner ||= 0;
	if ($useBanner) {
		print "======================================\n== ";
	}
	print "$s";
	if ($useBanner) {
		print "======================================\n";
	}
	return;
}

1;


