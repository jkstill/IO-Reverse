
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
	$args->{CHUNKSIZE} ||= 1024;
	#$args->{F_OFFSET} = ($args->{CHUNKSIZE} + 2) * -1; # offset continually decrements to allow reverse seek
	$args->{F_OFFSET} = $args->{CHUNKSIZE} * -1; # offset continually decrements to allow reverse seek
	$args->{BOF} = 0; # true/false - have we reached beginning of file
	$args->{SEND_BOF} = 0; # true/false - have we reached beginning of file

	#die "CHUNKSIZE: $args->{CHUNKSIZE}\n";

	# set to EOF minus offset 
	# offset to avoid the end of line/file characters
	$fh->seek($fh->getpos, SEEK_END);
	$args->{F_POS} =  $fh->getpos;
	$args->{DEBUG} ||= 0;
	$debug=$args->{DEBUG};

	my $self = bless $args, $class;
	return $self;
}

{

my @data=();

sub next {
	my ($self) = @_;

	print "====================================\n" if $debug;

	my $returnLine='';

	if ( !$self->{SEND_BOF} && ( abs($self->{F_OFFSET}) > $self->{F_SIZE} ) ) { 
		# have reached the beginning of the file
		print "setting BOF = 1\n" if $debug;
		$self->{BOF} = 1;
	}

	if ($debug) {
		print "F_OFFSET: $self->{F_OFFSET}\n";
		print "  F_SIZE: $self->{F_SIZE}\n";
	}

	if ( ! $self->{BOF}  && ! $self->{SEND_BOF} ) {

		print "outer if\n" if $debug;

		while (1) {

			$self->{FH}->seek($self->{F_OFFSET}, 2);  # 2 is seek to EOF

			if ( $debug ) {
				my $tell = tell $self->{FH};
				my $posFromEOF = $self->{F_SIZE} + $self->{F_OFFSET};
				print "TELL: $tell\n";
				print "Pos/EOF: $posFromEOF\n";
			}


			#my $char = $self->{FH}->getc;
			my $buffer='';

			if ($debug) {
				print "CHUNKSIZE: $self->{CHUNKSIZE}\n";
				print " F_OFFSET: $self->{F_OFFSET}\n";
			}

			my $readSize = read($self->{FH}, $buffer, $self->{CHUNKSIZE}); #, $self->{F_OFFSET} );

			if ($debug) {
				print " readSize: $readSize\n";
				print "   buffer: $buffer\n";
			}
			
			#$returnLine = $buffer;
			#last;
			if ( $buffer =~ /\n/ ) {
				my @a = split(/\n/,$buffer);
				$returnLine = pop @a;
				$self->{F_OFFSET} -= length($returnLine) + 1;
				last;
			} else {
				$returnLine .= $buffer;
			}

			$self->{F_OFFSET} -= $self->{CHUNKSIZE};

			if ($debug) {
				print "EOL F_OFFSET: $self->{F_OFFSET}\n";
			}

			#last if $char eq "\n";
			#$line = $char . $line; 
			# just for fun, the line will be reversed
			#$line .= $char ;
		}
	} elsif ($self->{SEND_BOF}) { # is BOF

			if ( $debug ) {
				print 'SEND_BOF: ' . Dumper(\@data) . "\n";
				my $tell = tell $self->{FH};
				print "TELL: $tell\n";
			}

			if (scalar @data) {
				$returnLine = pop @data;
			} else { 
				return undef;
			}
	} elsif ($self->{BOF}) { # is BOF
		#$self->{FH}->seek($self->{F_OFFSET}+1, 2);  # 2 is seek to EOF
		$self->{FH}->seek(0, 0);  # 2 seek to BOF
		my $buffer;
		my $readSize = read($self->{FH}, $buffer, $self->{CHUNKSIZE}); #, $self->{F_OFFSET} );
		@data = split(/\n/,$buffer);
		#print 'BOF: ' . Dumper(\@data) . "\n";
		pop @data;
		$self->{BOF}=0;
		$self->{SEND_BOF}=1;
		if ($debug) {
			print "setting SEND_BOF\n";
			print "     BOF: $self->{BOF}\n";
			print "SEND_BOF: $self->{SEND_BOF}\n";
		}
		$returnLine = pop @data;
	} else {
		die "error in IO:Reverse\n";
	}

	print "returning $returnLine\n" if $debug;

	return "$returnLine\n";

}

}

1;


