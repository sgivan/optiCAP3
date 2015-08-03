#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  create_new_contigs_from_layout.pl
#
#        USAGE:  ./create_new_contigs_from_layout.pl  
#
#  DESCRIPTION:  Script to create new contigs from a cap3
#                   assembly based on the "layout".
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Dr. Scott A. Givan (sag), givans@missouri.edu
#      COMPANY:  University of Missouri, USA
#      VERSION:  1.0
#      CREATED:  08/03/15 15:17:12
#     REVISION:  ---
#===============================================================================

use 5.010;      # Require at least Perl version 5.10
use autodie;
use Getopt::Long; # use GetOptions function to for CL args
use warnings;
use strict;
use IO::File;
use IO::Handle;

my ($debug,$verbose,$help,$infofile,$seqfile,$extractseq,$minleftclip,$minrightclip);

my $result = GetOptions(
    "debug"     =>  \$debug,
    "verbose"   =>  \$verbose,
    "help"      =>  \$help,
    "info:s"      =>  \$infofile,
    "seq:s"       =>  \$seqfile,
    "extractseq:s"  =>  \$extractseq,
    "minleftclip:i" =>  \$minleftclip,
    "minrightclip:i"    =>  \$minrightclip,
);

if ($help) {
    help();
    exit(0);
}


$infofile ||= 'infofile';
$seqfile ||= 'seqfile';
$extractseq ||= `which extractseq`;
chomp($extractseq);


if ($debug) {
    say "infofile: '$infofile'\nseqfile: '$seqfile'\nextractseq: '$extractseq'";
}

my @clip = ();
my $fh_info = IO::File->new();
if ($fh_info->open("< $infofile")) {
        @clip = grep( /^Clip/, <$fh_info>);
}

say @clip if ($debug);

for my $clipdata (@clip) {
    my ($seqname,$leftclip,$rightclip,$length,$rightsize);

    # lines look like this:
    # Clip C158 left clip: 1, right clip: 226,  length: 3272,  right size 3046
    # Clip C133 left clip: 5043, right clip: 5271,  length: 5271,  right size 0
    #
    if ($clipdata =~ /Clip\s(.+?)\sleft\sclip:\s(\d+),\s+right\sclip:\s(\d+),\s+length:\s+(\d+),\s+right\ssize\s(\d+)/) { 
        $seqname = $1;
        $leftclip = $2;
        $rightclip = $3;
        $length = $4;
        $rightsize = $5;

        if ($debug) {
           print "seqname: '$seqname', ";
           print "left clip: '$leftclip', ";
           print "right clip: '$rightclip', ";
           print "length: '$length', ";
           print "right size: '$rightsize'\n";
       }
   }

   if ($leftclip > $minleftclip) {
       my $outfilename = "$seqname" . "_1-$leftclip";
        open(EX, "|-", "$extractseq -sequence $seqfile:$seqname -regions 1-$leftclip -outseq $outfilename");
        close(EX);
    }
    
}

sub help {

    say <<HELP;

    "debug"     =>  \$debug,
    "verbose"   =>  \$verbose,
    "help"      =>  \$help,
    "info"      =>  \$infofile,
    "seq"       =>  \$seqfile,

HELP

}



