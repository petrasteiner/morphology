=pod

=head1  Skript: Depthofwordstructure 

Version 1.0                                                

=head1 Author 

Petra C. Steiner

=head1 CALL                                                        

perl Depthofwordstructure                                          

=head1 Description  

This is a simple Perl script for the calculation of the depth of subtrees of words            
                                                             
 Quick start:                                              
                                                             
 1. Install Perl 5.14 for Linux                                
 2. Put the Input files into the same folder as this program 
 3. Install all missing packages                             
 4. Start the program by "perl Depthofwordstructure.pl" or with flags -d DIR -l Level -i File                
                                                             
  Input Files:                                               
  here GMOLoutputneworthography_analyseswithcelex6.out, generated from the CELEX database                    
  within the same folder, if no other filename oder directory name is provided                                   
                                                             
 Files generated:   here if no flags are being used GMOLoutputneworthography_analyseswithcelex6.out.structures           
                                                             
 No hash files for internal usage:                                                        
                                                             
=cut

#!/usr/bin/perl -w 


use strict;

use warnings;
use Getopt::Long;
use File::Basename;

use open ':utf8';
use utf8;

use locale;

#binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";
#binmode STDERR, ":encoding(UTF-8)";

BEGIN 
{
    our $start_run = time(); 
}

$| = 1;

my(
 	# $help,
	$helpfile,
    $sInputFilename,
	$sInputDir,
    $soutputfile,
	$soutputfileallanalyses,
	@aFileList,
	$nfile,
    $linecounter,
    $sLine,
    $lemma,
    $tree,
    @splittree,
    $charofsplittree,
    $depthstructure,
    $depth,
	$level,
   #%hfile,
	$cwd,
	$pathname,
	$base,
   );

$helpfile = "GNcompoundswithCELEXRDF.help";
$cwd = `pwd`; # current path
chomp $cwd;
$level = "1";

$sInputFilename = "$cwd\/filesGN17\/nomen.Artefakt.xml_analyseswithcelex6.out";
$soutputfile = $sInputFilename . ".structures";
# if not defined by options

GetOptions(
    'i=s' => \$sInputFilename,
    'd=s' => \$sInputDir,
	'l=s' => \$level,
    # 'h' =>  \$help,
    );
	
# if ($help)
# {
    # # print "Helpfile: $helpfile";
    # open (HELP, '<', $helpfile) or die "couldn't open $helpfile: $!"; 
    # while (<HELP>) 
    # {print $_}; 
    # close HELP;
    # exit;
# }	

if ($sInputDir) 
{
    chdir $sInputDir or die "chdir $sInputDir: $!";
    @aFileList = glob ("nomen*\_analyseswithcelex$level.out");
    $pathname = dirname($aFileList[0]);
    $base = basename($aFileList[0]);
    $soutputfileallanalyses =  "$pathname\/Allin$sInputDir$level\.structures";
}

else # just one file
{  
    push(@aFileList, $sInputFilename);
    $pathname = dirname($sInputFilename);
    $base = basename($sInputFilename);
    if ( ! -e $sInputFilename) {print "$sInputFilename does not exist. Please choose another GermaNet inputfile in XML format."; exit(0)};
    $soutputfileallanalyses =  "$pathname\/$base\.structures";	
}

$nfile = 0;

open (AUSGABE1, ">$soutputfileallanalyses") || die "Fehler! ";


foreach $sInputFilename (@aFileList)
{
    $nfile++;
    $base = basename($sInputFilename);
	$soutputfile =  "$pathname\/$base\.structures";
	open (AUSGABE2, ">$soutputfile") || die "Fehler! ";
	open my $INPUT, '<:encoding(UTF-8)', $sInputFilename 
     || die "can't open UTF-8 encoded filename: $!";

	$linecounter = 0;
	print "\n Production starts for $sInputFilename.\n";
	foreach $sLine (<$INPUT>)
	{
		chomp($sLine);
		if ($sLine =~ /^(.*)\t(.*)$/)
		{
		$linecounter++;
		$lemma = $1;
		$tree = $2;
	#	print "Tree: $tree\n";
		$depth = 0;
		$depthstructure = "";
		@splittree = split //, $tree;
#		print "@splittree\n";
		foreach $charofsplittree (@splittree)
		{
			if ($charofsplittree eq "\(")
			{
			$depth++;
			$depthstructure = $depthstructure . "\($depth ";
			}	
			elsif ($charofsplittree eq "\)")
				{
				$depth--;
				$depthstructure =~ s/\s+$//;  #righttrim	
				$depthstructure = $depthstructure . "\)";
			}
			else
			{
			# nothing 
			}
		}
		if ($depthstructure eq "") # simple conversion as ruhen from Ruhe
		{
			$depthstructure = "(1)";  
		}
	    print AUSGABE1 "$lemma\t$tree\t$depthstructure\n";
		print AUSGABE2 "$lemma\t$tree\t$depthstructure\n";
		print "$lemma\t$tree\t$depthstructure\n";
		}
		else
		{
	print "Could not process Line $sLine\n";
		}
	}
	close AUSGABE2;
	print "valid lines of inputfile: $linecounter \n";
}
close AUSGABE1;

END
{
    my $end_run = time();
    my $run_time = $end_run - our $start_run;
    print "Job took $run_time seconds\n";
    exit 0;
}

