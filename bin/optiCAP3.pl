#!/usr/bin/env perl
# $Id: optiCAP3.pl,v 1.10 2005/05/04 15:58:17 givans Exp $
# $Log: optiCAP3.pl,v $
# Revision 1.10  2005/05/04 15:58:17  givans
# Added -z 1 -p 66 options to cap3 invocation.
#
# Revision 1.9  2005/04/28 05:19:55  givans
# Added -O option to send alignent to STDOUT.
#
# Revision 1.8  2005/04/28 01:39:07  givans
# *** empty log message ***
#
# Revision 1.7  2004/02/19 01:21:00  givans
# Added more command-line option handling
# Added comments
#
# Revision 1.6  2004/02/19 01:11:26  givans
# *** empty log message ***
#
use strict;
use Carp;
use File::Copy;
use Getopt::Std;
use vars qw/ $opt_f $opt_o $opt_h $opt_v $opt_O /;




#################################################
#	Variable Declarations			#
#################################################

my($file_in, $file_out, $file_log, $file_info, $verbose,@alignment);
my $cap3_opt = '-z 1 -p 66';

################################################*
#   Determine processor type                    #
################################################*
my $cap3 = '/ircf/ircfapps/bin/cap3';

my $lscpu = `lscpu`;
chomp($lscpu);
#print "cpu: '$lscpu'\n";
if ($lscpu =~ /AuthenticAMD/) {
    $cap3 .= ".opteron" if (-x $cap3 . ".opteron");
} elsif ($lscpu =~ /Intel/) {
    $cap3 .= ".intel" if (-x $cap3 . ".intel");
}
print "using '$cap3'\n" if ($verbose);

#################################################
#	Gather User Input			#
#################################################


getopts('f:vho:O');

if ($opt_h) {# Print help menu if -h is given
print <<HELP;

This script optimizes CAP3 parameters

usage:  optiCAP3.pl -f <input file>

Command-line Options	Description
    -f			input file name
    -o			output file name [optional]
    -O			send alignment to terminal
    -v			verbose output to terminal
    -h			print this help menu

HELP
exit(0);
}

$verbose = 1 if ($opt_v);

if ($ARGV[0]) {
  if (-e $ARGV[0]) {
    $file_in = $ARGV[0];
  } else {
    print "$ARGV[0] doesn't exist.\n";
    exit;
  }
} elsif ($opt_f) {
  if (-e $opt_f) {
    $file_in = $opt_f;
  } else {
    print "$opt_f doesn't exist.\n";
    exit;
  }
} else {
  print "What file do you want to use? ";
  chomp($file_in = <STDIN>);
  if (!-e $file_in) {
    print "$file_in doesn't exist.\n";
    exit;
  }
}

if (!$opt_O) {
if ($opt_o) {
  $file_out = $opt_o;
} else {
  $file_out = "$file_in" . ".out";
}
}


$file_log = "$file_in" . ".log";

open(LOG,">$file_log") or die "can't open '$file_log': $!";

if ($verbose) {
  print LOG "Running CAP3:  $cap3 $file_in $cap3_opt > $file_out\n";
}

#
# Start first cap3 run
#

if (!$opt_O) {
  open(CAP3, "| $cap3 $file_in $cap3_opt > $file_out") or die "can't open $cap3: $!";
} else {
  open(CAP3, "| $cap3 $file_in $cap3_opt") or die "can't open $cap3: $!";
  @alignment = <CAP3>;
}
close(CAP3);

if ($?) {
  print LOG "can't close $cap3 (returned '$?'): $!";
  print "can't close $cap3 (returned '$?'): $!";
  print "\n";
  exit;
}

$file_info = $file_in . ".cap.info";
print LOG "opening '$file_info'\n" if ($verbose);
open(INFO,"$file_info") or die "can't open '$file_info': $!";

my @info = <INFO>;

close(INFO);

my %clips;
for (my $i = 0; $i < scalar(@info); ++$i) {
  my ($read,$clip,$dir,$clip5,$clip3) = ();
  if ($info[$i] =~ /^No\soverlap.+?read\s([\w_\.\-\|]+)$/) {
    $read = $1;
    $clips{$read} = [250,250] unless ($clips{$read});
    if ($info[$i + 1] =~ /\W*([35]).+?overlaps:\s(\d+)\s/) {
      $dir = $1;
      $clip = $2;

      if ($dir == 5) {
	$clip5 = "$clip";
	$clips{$read}->[0] = $clip5;
      } elsif ($dir == 3) {
	$clip3 = "$clip";
	$clips{$read}->[1] = $clip3;
      }

    }

  }
}

if (%clips) {
  my $file_clip = "$file_in" . ".clipping.txt";
  print "determining clipping parameters for $file_in sequences\n" if ($verbose);
  print LOG "determining clipping parameters for $file_in sequences\n";

  open(CLIP,">$file_clip") or die "can't open '$file_clip: $!";

  while (my($read,$clip) = each %clips) {

    print LOG "\noptimizing $read ...\n";
    print "\noptimizing $read ...\n" if ($verbose);
    print CLIP "$read\t$clip->[0]\t2\t$clip->[1]\t2\n";
    print "$read\t$clip->[0]\t2\t$clip->[1]\t2\n" if ($verbose);
    print LOG "$read\t$clip->[0]\t2\t$clip->[1]\t2\n";

  }
  close(CLIP);

  print "\n\nRerunning CAP3 with optimization\nNew CAP3 output:\n\n" if ($verbose);
  if (!$opt_O) {
  if (!$opt_v) {
    open(CAP3OPT, "| $cap3 $file_in $cap3_opt -w $file_clip >> $file_out" . ".opt.txt") or die "can't open CAP3OPT: $!";
  } else {
    open(CAP3OPT, "| $cap3 $file_in $cap3_opt -w $file_clip | tee $file_out" . ".opt.txt") or die "can't open CAP3OPT: $!";
  }
  } else {
    open(CAP3OPT, "| $cap3 $file_in $cap3_opt -w $file_clip") or die "can't open CAPOPT: $!";
    @alignment = <CAP3OPT>;
  }
  close(CAP3OPT);

  if ($?) {
    print LOG "can't close CAP3OPT pipe (returned '$?'): $!";
    print "can't close CAP3OPT pipe (returned '$?'): $!";
    exit;
  } else {
    print LOG "\n\nCAP3OPT closed successfully\n" if ($verbose);
  }
} else {
  print LOG "no clipping information\n" if ($verbose);
}

if ($opt_O) {
  print @alignment;
}

EXIT: {
  print LOG "\nexiting program\n";
  close(LOG);
}

