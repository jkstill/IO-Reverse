
=head1 ABSTRACT

 A simple module used to provide optional debugging 
 and informational messages

=head1 SYNOPSIS

 use Verbose;

  my $d = Verbose->new(
  {
    VERBOSITY=>3, 
    LABELS=>1, 
    TIMESTAMP=>1, 
    HANDLE=>*STDERR
    } 
  );

 my %h=(a=>1, b=>2, c=>3);

 print "doing some work with \%h\n";
 $d->print(2,'reference to %h', \%h);

 HANDLE will default to *STDOUT if not specified

=head1 DESCRIPTION

This module is used to enable varying levels of verbose
output from your Perl scripts. 

The levels are 1..N

=head1 AUTHOR

	Jared Still jkstill@gmail.com

=cut

package Verbose;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(new showself print);
our $VERSION = '0.02';

use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);

=head2 new

 Create a new Verbose object

 my $verbosity=2;
 my $useTimestamp=1;

 my $d = Verbose->new(
    {
       VERBOSITY=>$verbosity,
       LABELS=>1,
       TIMESTAMP=>$useTimestamp,
       HANDLE=>*STDERR
    }
 );


=cut


sub new {

	use Data::Dumper;
	use Carp;

	$Data::Dumper::Terse=1;

	my $pkg = shift;
	my $class = ref($pkg) || $pkg;
	#print "Class: $class\n";
	my ($args) = @_;
	#print 'args: ' , Dumper($args);
		
	# handle could be stdout,stderr, filehandle, etc
	my $self = { 
		VERBOSITY=>$args->{VERBOSITY}, 
		LABELS=>$args->{LABELS}, 
		HANDLE=>$args->{HANDLE},
		TIMESTAMP=>$args->{TIMESTAMP},
		CLASS=>$class 
	};

	#$self->{LABELS}=0 unless defined $self->{LABELS};
	$self->{HANDLE}=*STDOUT unless defined $self->{HANDLE};

	#print Dumper($self);
	{ 
		no warnings;
		if ( (not defined $self->{VERBOSITY}) || (not defined $self->{LABELS}) ) { 
			warn "invalid call to $self->{CLASS}\n";
			warn "call with \nmy \$a = $self->{CLASS}->new(\n";
			warn "   {\n";
			warn "      VERBOSITY=> (level - 0 or 1-N),\n";
			warn "      LABELS=> (0 or 1)\n"; 
			warn "   }\n";
			croak;
		}
	}
	my $retval = bless $self, $class;
	return $retval;
}

=head2 showself

  Simply dump the class attributes

 $d->showself;

 $VAR1 = bless( {
                 'CLASS' => 'Verbose',
                 'HANDLE' => *::STDERR,
                 'VERBOSITY' => 2,
                 'TIMESTAMP' => 0,
                 'LABELS' => 1
               }, 'Verbose' );

=cut 

sub showself {
	use Data::Dumper;
	my $self = shift;
	print Dumper($self);
}

=head2 getlvl

 Return the level of verbosity set when new was called:
 This is useful to prevent calling verbose->print when 
 the verbosity level is 0. As the print method returns
 quite early if the verbosity level is too low, the
 savings from doing this may be negligible.

 $d->getlvl && $d->print(2,'reference to %h', \%h);

=cut

sub getlvl {
	my $self = shift;
	$self->{VERBOSITY};
}

=head2 print
 
 Call print with verbosity level, label and data

 $d->print(2,"This is a label",[0,1,2])
 $d->print(4,'anonymous array ref', [7,8,9]);

 returns 0 if nothing printed
 returns 1 if content printed
 
=cut

sub print {
	use Carp;
	my $self = shift;
	my @t=();
	my ($verboseLvl,$label, $data) = (0,'',\@t);
	($verboseLvl,$label, $data) = @_;

	return 0 unless ($verboseLvl <= $self->{VERBOSITY} );

	# handle could be stdout,stderr, filehandle, etc
	my $handle = $self->{HANDLE};

	my $padding='  ' x $verboseLvl;

	my $isRef = ref($data) ? 1 : 0;

	unless ($isRef) {carp "Must pass a reference to $self->{class}->print\n" }

	my $refType = ref($data);
	#print "reftype: $refType\n";

	my $wallClockTime='';
	if ( $self->{TIMESTAMP} ) {
		# include microseconds via gettimeofday()
		$wallClockTime = strftime("%Y-%m-%d %H:%M:%S",localtime) . '.' . sprintf("%06d",(gettimeofday())[1]);
	}

	print $handle "$wallClockTime$padding======= $label - level $verboseLvl =========\n" if $self->{LABELS} ;
	
	my $isThereData=0;

	if ('ARRAY' eq $refType) {
		if (@{$data}) {
			print $handle $padding, join("\n" . $padding, @{$data}), "\n";
			$isThereData=1;
		}
	} elsif ('HASH' eq $refType) {
		#print "HASH: ", Dumper(\$data);
		if (%{$data}) {
			foreach my $key ( sort keys %{$data} ) {
				print $handle "${padding}$key: $data->{$key}\n";
			}
			$isThereData=1;
		}
	} else { croak "Must pass reference to a simple HASH or ARRAY to  $self->{CLASS}->print\n" }

	# no point in printing a separator if an empty hash or array was passed
	# this is how to do label only
	print $handle "$padding============================================\n" if $self->{LABELS} and $isThereData;

	return 1;
}

=head1 Example Usage 

Three levels of verbosity will be set

 1. show function name
 2. show internal function messages
 3. dump data structures

 Optional messages are passed in the array []

=head2 Procedural

 use Avail::Check::Tools::Verbose qw( showself print);
 use Data::Dumper;
 $Data::Dumper::Deparse=1;
 use strict;
 use warnings;
 
 sub getVerboseFnameLvl {return 1}
 sub getVerboseDetailLvl {return 2}
 sub getVerboseDumpLvl {return 3}

 my $verbosity=2;

 my $v = Avail::Check::Tools::Verbose->new(
   {
     VERBOSITY=> $verbosity,
     LABELS=>1,
     TIMESTAMP=>1,
     HANDLE=>*STDERR
   }
 );


 $v->print(1,'testing',[]);

 vcheck ($v);

 sub vcheck {
   my ($v) = @_;  

   my $fname = (caller(0))[3];

   $v->print(getVerboseFnameLvl(),$fname,[]);
   $v->print(getVerboseDetailLvl(),'This is an internal process',[]);

   # nothing printed unless verbosity set to 3+
   my @a=(0,1,2,3);
   my %h=( a => 'A', b => 'B');

   $v->print(getVerboseDumpLvl(),'contents of an array', \@a );
   $v->print(getVerboseDumpLvl(),'contents of a hash', \%h );

   # use Dumper
   $v->print(getVerboseDumpLvl(),'Dumping an an array', [ Dumper(\@a) ] );
   $v->print(getVerboseDumpLvl(),'Dumping a hash', [ Dumper(\%h) ] );

   return;  
 }

=head2 Object Oriented

 use warnings;
 use strict;

 # object based

 my $v = Vtest->new( { VERBOSITY => 3 } );
 $v->vcheck();

 package Vtest;

 use Data::Dumper;
 use Avail::Check::Tools::Verbose qw( showself print);

 sub getVerboseFnameLvl {return 1}
 sub getVerboseDetailLvl {return 2}
 sub getVerboseDumpLvl {return 3}

 sub new {

   my $pkg = shift;
   my $class = ref($pkg) || $pkg;
   my $parmHash = shift;

   my $self->{PARMS} = $parmHash;

   $self->{VERBOSE} = Avail::Check::Tools::Verbose->new(
      {
         VERBOSITY=>$parmHash->{VERBOSITY},
         LABELS=>1,
         TIMESTAMP=>1,
         HANDLE=>*STDERR
      }
   );

   my $retval = bless $self, $class;
   return $retval;
 }

 sub vcheck {
   my $self = shift;

   my $fname = (caller(0))[3];

   $self->{VERBOSE}->print(getVerboseFnameLvl(),$fname,[]);
   $self->{VERBOSE}->print(getVerboseDetailLvl(),$fname,[]);

   # nothing printed unless verbosity set to 3+
   my @a=(0,1,2,3);
   my %h=( a => 'A', b => 'B');

   $v->{VERBOSE}->print(getVerboseDumpLvl(),'contents of an array', \@a );
   $v->{VERBOSE}->print(getVerboseDumpLvl(),'contents of a hash', \%h );

   # use Dumper
   $v->{VERBOSE}->print(getVerboseDumpLvl(),'Dumping an array', [ Dumper(\@a) ] );
   $v->{VERBOSE}->print(getVerboseDumpLvl(),'Dumping a hash', [ Dumper(\%h) ] );

   return;  
 }

1;

=cut

1;

