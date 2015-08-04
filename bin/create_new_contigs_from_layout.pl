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

my ($debug,$verbose,$help,$infofile,$seqfile,$extractseq,$minlclip,$minrclip,$rename_int,$minlength,$deletefile);

my $result = GetOptions(
    "debug"     =>  \$debug,
    "verbose"   =>  \$verbose,
    "help"      =>  \$help,
    "info:s"      =>  \$infofile,
    "seq:s"       =>  \$seqfile,
    "extractseq:s"  =>  \$extractseq,
    "minlclip:i" =>  \$minlclip,
    "minrclip:i"    =>  \$minrclip,
    "rename:i"      =>  \$rename_int,
    "delete"        =>  \$deletefile,
    "minlength:i"   =>  \$minlength,
);

if ($help) {
    help();
    exit(0);
}


$infofile ||= 'infofile';
$seqfile ||= 'seqfile';
$extractseq ||= `which extractseq`;
chomp($extractseq);
$minlclip ||= 50;
$minrclip ||= 50;
my $integer = $rename_int if ($rename_int);
$minlength ||= 300;

#if ($integer) {
#    say "renaming, starting with '$integer'";
#    exit();
#}


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
    my ($seqname,$lclip,$rclip,$length,$rightsize);

    # lines look like this:
    # Clip C158 left clip: 1, right clip: 226,  length: 3272,  right size 3046
    # --> removes 227-3272 from C158
    # Clip C133 left clip: 5043, right clip: 5271,  length: 5271,  right size 0
    # --> removes 1-5043 from C133
    # Clip C54 left clip: 325, right clip: 27061,  length: 27939,  right size 878
    #
    if ($clipdata =~ /Clip\s(.+?)\sleft\sclip:\s(\d+),\s+right\sclip:\s(\d+),\s+length:\s+(\d+),\s+right\ssize\s(\d+)/) { 
        $seqname = $1;
        $lclip = $2;
        $rclip = $3;
        $length = $4;
        $rightsize = $5;

        if ($debug) {
           print "seqname: '$seqname', ";
           print "left clip: '$lclip', ";
           print "right clip: '$rclip', ";
           print "length: '$length', ";
           print "right size: '$rightsize'\n";
       }
   }

    if ($lclip >= $minlclip && $rightsize < $minrclip) {
        # don't bother unless the resulting squence > minimum length
        if ($lclip <= $minlength) {
            say "skipping $seqname based on lclip: $lclip < $minlength" if ($debug);
            next;
        }
        my $outfilename = "$seqname" . "_1-$lclip.fa";
        open(EXSQ, "|-", "$extractseq -sformat fasta -auto -sequence $seqfile:$seqname -regions 1-$lclip -outseq $outfilename");
        close(EXSQ);
        $integer = renamefile($outfilename,$integer) if ($rename_int);
    } elsif ($rightsize >= $minrclip) {
        my $diff = $rclip - $lclip;
        if ($diff < $minlength) {
            say "skipping $seqname based on rclip - lclip: $diff < $minlength" if ($debug);
            #say "skipping $seqname based on rclip - lclip < $minlength" if ($debug);
            next;
        }
        my $outfilename = "$seqname" . "_$lclip-$rclip.fa";
        open(EXSQ, "|-", "$extractseq -auto -sequence $seqfile:$seqname -regions $lclip-$rclip -outseq $outfilename");
        close(EXSQ);
        $integer = renamefile($outfilename,$integer) if ($rename_int);
    }
    
}

sub renamefile {
    my $infile = shift;
    my $integer = shift;
    my $mapfilename = 'mapfile.txt';

    open(MAP, ">>", $mapfilename);

    say "renaming '$infile' to C" . "$integer.fa" if ($debug);
    say MAP "renaming '$infile' to C" . "$integer.fa";

    close(MAP);

    open(SED, "|-", "sed -E 's/>.+/>C$integer/' $infile > C" . "$integer.fa");
    if (close(SED)) {
        unlink($infile) if ($deletefile);
    }
    return ++$integer;
}

sub help {

    say <<HELP;

    "debug"
    "verbose"
    "help"  
    "info"          name of *info file created by cap3 
    "seq"           name of file containing input sequences 
    "extractseq:s"  path to extractseq (EMBOSS package) -- will try to find it automatically
    "minlclip:i"    minimum left clip to accept [default = 50]
    "minrclip:i"    minimum right clip to accept [default = 50]
    "rename:i"      rename the files and sequences -- argument should be an integer
                    script will rename files/sequences starting with integer
    "delete"        delete the original files after renaming
    "minlength:i"   minimum sequence length to create a new contig file

HELP

}



