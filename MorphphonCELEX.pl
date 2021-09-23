=pod

=head1  Skript: MorphonCELEX.pl  

Version 1.0                                                

=head1 Author 

Petra C. Steiner, Institute for German Linguistics, FSU Jena     
petra.steiner@daad-alumni.de                     

=head1 CALL                                                        

perl MorphonCELEX.pl                                            

=head1 Description  

This is a simple Perl script for the conversion of CELEX gpl.cd to a modernized version.                  
                                                             
 Quick start:                                              
                                                             
 1. Install Perl 5.14 for Linux                                
 2. Put the Input files into the same folder as this program 
 3. Install all missing packages                             
 4. Start the program by "perl MorphoCELEX.pl"                 
                                                             
  Input Files:                                               
  gpl.cd and GOL.CD of the CELEX database                    
  within the same folder                                     
                                                             
 Files generated:                                            
 GPOLoutputintermediate: revised umlauts and sz of lemmas    
 GPOLoutput: above plus further repairs - this is old spelling before the reform with corrected diacritics
 GPOLoutneworthography: GPL transformed to modern spelling
 GPOLoutputmatchingphons: GPL with revised phonological analyses          
                                                             
 Checkfile: some words whose recycling could go wrong (e.g. with double ae  
            (currently no problems as they are treated explicitly in the program
 Checkfile2:                                 
                                                             
 Hash files for internal usage:                              
 gplhash  GOLhash GPOLintermediatehash  GPOLoutputhash                
 GPOLoutputreformedhash  GPOLoutputmatchingphonshash                        
                                                             
=cut

#!/usr/bin/perl -w 


use strict;

use warnings;
#use Getopt::Long;
use DB_File;
use Fcntl 'O_RDWR', 'O_WRONLY', 'O_CREAT';
use Tie::File;
use MLDBM qw (DB_File Storable);

# in case that Storable is not installed uncomment the following line
#use MLDBM qw (DB_File);

# use Sort::Key::Top qw(nkeytop rnkeytop rnkeytopsort);

use open ':utf8';
use utf8;

use locale;

binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

use Data::Dumper qw(Dumper);
$Data::Dumper::Useperl = 1;
# $Data::Dumper::Terse = 1;

use FreezeThaw;
use DBM_Filter;

#use Math::Combinatorics;

#use List::Util qw(first sum reduce max);
#use List::MoreUtils qw(uniq indexes any);
#use List::Gen;
#use Sort::Naturally;
#use Sort::Versions;
use Sort::Key::Natural qw(natkeysort);

BEGIN 
{
    our $start_run = time(); 
}

$| = 1;

my($nReturnValueFilename1,
   $nReturnValueFilename2,
   $nReturnValueFilename3,
   $sphonhashFilename,
   $sorthhashFilename,
   $sFilename,
   $sphonwithorthFilename,
   $db,
   %hfile);

$sphonhashFilename = "gplhash";

# if gplhash has been generated use this file (later: no consequences)

if (-e $sphonhashFilename)
{
    print "\n Loading hash file of gpl\n";
    $db = tie (%hfile, 'MLDBM', "$sphonhashFilename", 
	 O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $sphonhashFilename";
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    undef $db;
    untie (%hfile); 
}

else
# create it

{
    $sFilename = "gpl.cd";

    if ( ! -e $sFilename) {die "$sFilename does not exist."};
    $nReturnValueFilename1 = put_indexedfile_in_hash($sFilename, $sphonhashFilename);
    $db = tie (%hfile, 'MLDBM', "$sphonhashFilename", 
	       O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $sphonhashFilename";
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    undef $db;
    untie (%hfile); 
}

$sorthhashFilename = "GOLhash";

if (-e $sorthhashFilename)
{
    print "\n Loading hash file of GOL\n";
    $db = tie (%hfile, 'MLDBM', "$sorthhashFilename", 
	 O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $sorthhashFilename";
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    undef $db;
    untie (%hfile);
}

else
# create it
{
    $sFilename = "GOL.CD";
    if ( ! -e $sFilename) {die "$sFilename does not exist."};
    $nReturnValueFilename2 = put_indexedfile_in_hash($sFilename, $sorthhashFilename);
 
    $db = tie (%hfile, 'MLDBM', "$sorthhashFilename", 
	 O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $sorthhashFilename";
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    undef $db;
    untie (%hfile);
}

$sphonwithorthFilename = "GPOLintermediatehash";

$nReturnValueFilename3 = create_data_with_diacritics($sphonhashFilename, $sorthhashFilename, $sphonwithorthFilename);

$sFilename = "GPOLoutputintermediate";
print "Output file:  $sFilename.\n\n";

$nReturnValueFilename2 = output_of_tied_hash($nReturnValueFilename3, $sFilename);

$sFilename = "GPOLoutputhash";

$nReturnValueFilename3 = change_orth_in_structures($sphonwithorthFilename, $sFilename);

$sFilename = "GPOLoutput";
$nReturnValueFilename2 = output_of_tied_hash($nReturnValueFilename3, $sFilename);

print "Output file: $sFilename.\n\n";

$sFilename = "GPOLoutputreformedhash";

$nReturnValueFilename2 = change_to_new_orthography($nReturnValueFilename3, $sFilename);

$sFilename = "GPOLoutputneworthography";

$nReturnValueFilename3 = output_of_tied_hash($nReturnValueFilename2, $sFilename);
print "Output of refurbished orthography in $sFilename.\n\n";

$sFilename = "GPOLoutputmatchingphonshash";
$nReturnValueFilename3 = change_phons_tosurface($nReturnValueFilename2, $sFilename);

$sFilename = "GPOLoutputmatchingphons";
$nReturnValueFilename2 = output_of_tied_hash($nReturnValueFilename3, $sFilename);

print "Final output in $sFilename.\n\n";

END
{
    my $end_run = time();
    my $run_time = $end_run - our $start_run;
    print "Job took $run_time seconds\n";
    exit 0;
}

sub put_indexedfile_in_hash 
{
    my ($sinputfile, $soutputfile) = @_;
    my (%hfile,
	@keys,
	$nReturnValue1,
	$sLine,
	$linecounter,
	$index,
	$entry,
	$hashsize,
	$db,
	);

    print "\n Put $sinputfile into hash.\n";

    open my $INPUT, '<:encoding(UTF-8)', $sinputfile 
     || die "can't open UTF-8 encoded filename: $!";


    $db = tie (%hfile, 'MLDBM', "$soutputfile",  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');

    $linecounter = 0;
    print "\n Hash production starts for $sinputfile.\n";
    foreach $sLine (<$INPUT>)
	     {
		 chomp($sLine);
		 if ($sLine =~ /^(\d+)\\(.*)$/)
		 {
		     $linecounter++;
		     $index = $1;
		     $entry = $2;
		     $hfile{$index} = $entry;
		 }
		 
	         else
		 {
		     print "Could not process Line $sLine\n";
		 }
	     }
    $hashsize = keys %hfile;
    undef $db;
    untie (%hfile);
    print "valid lines of inputfile: $linecounter , number of entries in hash (types): $hashsize \n";
    return ($soutputfile);
}


# creates phonological information with diacritics and special characters

sub create_data_with_diacritics 
{
    my ($sphoninputfile, $sorthinputfile, $sorthphonoutputfile) = @_;
    my (%hphon,
	%horth,
	%horthphon,
	$key,
	@keys,
	$nReturnValue1,
	$sLinephon,
	$sLineorth,
	$sLineorthphon,
	$linecounter,
	$unchangedcounter,
	#	$index,
	$word,
	$orthphonword,
	$rest,
	$entry,
	$hashsize,
	$db1,
	$db2,
	$dbout,
	$checkfile,
	);
    print "\nCreate data with diacritics.\n";


    $db1 = tie (%hphon, 'MLDBM', "$sphoninputfile", O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $sphoninputfile";
    $db2 = tie (%horth, 'MLDBM', "$sorthinputfile", O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $sorthinputfile";
# Das Hashergebnis in eine Datei schreiben
    Dumper($db1->{DB});

    $db1->{DB}->Filter_Push('utf8');

    Dumper($db2->{DB});

    $db2->{DB}->Filter_Push('utf8');

    $dbout = tie (%horthphon, 'MLDBM', "$sorthphonoutputfile",  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($dbout->{DB});
    $dbout->{DB}->Filter_Push('utf8');
    $linecounter = 0;
    $unchangedcounter = 0;

    $checkfile = "Checkfile";
    if(-e $checkfile) 
    {
	unlink $checkfile;
    }

    @keys = natkeysort { $_} keys %horth;

    foreach $key (@keys)
	{
#	    print "$key\n";
	    $linecounter++;
	    $sLinephon = $hphon{$key};
	    $sLineorth = $horth{$key};

# test if there is a special character
	    if ($sLineorth =~ /.*[\"|\#|\'|\$].*$/)
	    {
		## only the word/lemma is of interest, the rest could result to mistakes
	#	print "$sLinephon\n";
		$sLinephon =~ /^([^\\]+)(\\.*)$/;
		$word = $1;
		$rest = $2;
	#	print "W: $word R: $rest\n";
		$orthphonword = build_diacritic_form($sLineorth, $word, $checkfile);

		## build sLineorthphon
		$sLineorthphon = "$orthphonword$rest";
		$horthphon{$key} = $sLineorthphon;
	    }
	    else
	    {
		$horthphon{$key} = $sLinephon;
		$unchangedcounter++;
	    }
	}

    $hashsize = keys %horthphon;

    undef $db1;
    undef $db2;
    undef $dbout;
    untie (%horthphon);
    untie (%hphon);
    untie (%horth);

    print "valid lines of inputfile: $linecounter , unchanged: $unchangedcounter , number of entries in hash: $hashsize\n";
    return ($sorthphonoutputfile);
}


sub build_diacritic_form
{
    my ($sLineorth, $sLinephon, $checkfile) = @_;
    my ($sLineorthphon,
	$phonword,
	$orthword,
	$before,
	$offset,
	$result,
	);

# Here you can find critical cases that should be checked

    $sLinephon =~ /^(.*?)\\.*$/;
    $phonword = $1;
    $sLineorth =~ /^(.*?)\\.*$/;
    $orthword = $1;
    $sLineorthphon = $sLinephon;

    if ($orthword =~ /^(.*?)\$.*$/)  #sz
    {
      if ($phonword =~ /\.*(.)ss.*(.)ss/) # maybe problematic
      {
	  if ($1 eq $2)
	  {
	  open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
	  print AUSGABE "$phonword\n";
	  }
#error is reduced by heuristics: comparison of the two letters before ß is included
	
	  $sLineorthphon= substitute_multiple_characters($orthword, $sLineorthphon, 2, "\$", "ss", "\ß"); 
      }
      
      else
      {   
	  $sLineorthphon =~ s/ss/\ß/g; 
      }
    }
 
    if ($orthword =~ /^(.*?)\#e.*$/)  # accent acute
    {
      if ($phonword =~ /\.*(.)e.*(.)e/) # maybe problematic
      {
	  if ($1 eq $2)
	  {
	  open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
	  print AUSGABE "$phonword\n";
	  }
#error is reduced by heuristics: comparison of the two letters before e is included
	
	  $sLineorthphon= substitute_multiple_characters($orthword, $sLineorthphon, 2, "\#e", "e", "\é"); 
      }
      
      else
      {   
	  $sLineorthphon =~ s/e/\é/g; 
      }
    }
 
  # small caps

    if ($sLineorth =~ /.*\"a.*$/)  #ä
    {
	if ($phonword =~ /\.*ae(.).*ae(.)/)   # maybe problematic
	{
	    if ($1 eq $2)
	    {
		open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
		print AUSGABE "$phonword\n";
	    }
#error is reduced by heuristics: comparison of the two letters before ü is included
	    
	    $sLineorthphon= substitute_multiple_characters_behind($orthword, $sLineorthphon, -1, "\"a", "ae", "\ä"); 
	}
	
	else
	{   
	    $sLineorthphon =~ s/ae/\ä/g; 
	}
	if ($sLineorthphon =~ /.*[\+\\\(]Ae.*$/) # subcondition, if Ae is within analysis
	{
	    $sLineorthphon =~ s/Ae/\Ä/g;
	}
    }

    if ($sLineorth =~ /.*\"o.*$/)  #ö
    {
	if ($phonword =~ /\.*oe(.).*oe(.)/)  # maybe problematic
	{
	    if ($1 eq $2)
	    {
		open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
		print AUSGABE "$phonword\n";
	    }
#error is reduced by heuristics: comparison of the two letters before ü is included
	    
	    $sLineorthphon= substitute_multiple_characters_behind($orthword, $sLineorthphon, -1, "\"o", "oe", "\ö"); 
	}
	else
	{   
	    $sLineorthphon =~ s/oe/\ö/g; 
	}
	if ($sLineorthphon =~ /.*[\+\\\(]Oe.*$/) # subcondition, if Ue is within analysis
	{
	    $sLineorthphon =~ s/Oe/\Ü/g;
	}
    }  


########


    if ($sLineorth =~ /.*\"u.*$/)  #ü
    {
	if ($phonword =~ /\.*ue(.).*ue(.)/)   # maybe problematic
	{
	    if ($1 eq $2)    
	    {
		open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
		print AUSGABE "$phonword\n";
	    }
#error is reduced by heuristics: comparison of the two letters before ü is included
	    
	    $sLineorthphon= substitute_multiple_characters_behind($orthword, $sLineorthphon, -1, "\"u", "ue", "\ü"); 
	}
	
	else
	{   
	    $sLineorthphon =~ s/ue/\ü/g; 
	}
	
	if ($sLineorthphon =~ /.*[\+\\\(]Ue.*$/) # subcondition, if Ue is within analysis
	{
	    $sLineorthphon =~ s/Ue/\Ü/g;
	}
    }
    
    #big caps
    if ($sLineorth =~ /.*\"A.*$/)  #Ä
    {
	$sLineorthphon =~ s/Ae/\Ä/g;
	if ($sLineorthphon =~ /.*[\+\\\(]ae.*$/) # subcondition, if ae is within analysis
	{
	    $sLineorthphon = substitute_multiple_characters_behind($orthword, $sLineorthphon, -1, "\"A", "ae", "\ä"); 
	}
    }
    if ($sLineorth =~ /.*\"O.*$/)  #Ö
    {
	$sLineorthphon =~ s/Oe/\Ö/g;
	if ($sLineorthphon =~ /.*[\+\\\(]oe.*$/) # subcondition, if oe is within analysis
	{
	    $sLineorthphon = substitute_multiple_characters_behind($orthword, $sLineorthphon, -1, "\"O", "oe", "\ö");;
	}
    }
    if ($sLineorth =~ /.*\"U.*$/)  #Ü
    {
	$sLineorthphon =~ s/Ue/\Ü/g;
	if ($sLineorthphon =~ /.*[\+\\\(]ue.*$/) # subcondition, if ue is within analysis
	{
	    $sLineorthphon = substitute_multiple_characters_behind($orthword, $sLineorthphon, -1, "\"U", "ue", "\ü"); 
	}
    }
  return ($sLineorthphon);  
}


sub substitute_multiple_characters_behind {
    my ($orthword, $sLineorthphon, $nlengthofnext, $orthrepresentation ,$old, $new) =@_;
    my ($offset,
	$result,
	$next);
    $offset = 0;

    $result = index($orthword, $orthrepresentation, $offset);
    
    while ($result != -1) 
    {
	$next =  substr $orthword, $result - $nlengthofnext + 1, abs($nlengthofnext);
	$offset = $result + 1;

# substitution of diacritics to the correct environment
	$next =~ s/\"a/ae/g;
	$next =~ s/\"A/Ae/g;
	$next =~ s/\"o/oe/g;
	$next =~ s/\"O/Oe/g;
	$next =~ s/\"u/ue/g;
	$next =~ s/\"U/ue/g;
	$next =~ s/\$/\ß/g;
	$next =~ s/\#e/\é/g;

	
	$sLineorthphon =~ s/$old${next}/$new${next}/g;

	$result = index($orthword, $orthrepresentation, $offset);
    }
    return ($sLineorthphon);
}


sub substitute_multiple_characters {
    my ($orthword, $sLineorthphon, $nlengthofnext, $orthrepresentation ,$old, $new) =@_;
    my ($offset,
	$result,
	$next);
    $offset = 0;

    $result = index($orthword, $orthrepresentation, $offset);
    
    while ($result != -1) 
    {
	$next =  substr $orthword, $result - $nlengthofnext, abs($nlengthofnext);
	$offset = $result + 1;

# substitution of diacritics to the correct environment
	$next =~ s/\"a/ae/g;
	$next =~ s/\"A/Ae/g;
	$next =~ s/\"o/oe/g;
	$next =~ s/\"O/Oe/g;
	$next =~ s/\"u/ue/g;
	$next =~ s/\"U/ue/g;
	$sLineorthphon =~ s/${next}$old/${next}$new/g;
	$result = index($orthword, $orthrepresentation, $offset);
    }
    return ($sLineorthphon);
}

sub change_orth_in_structures 
{
    my ($sorthphoninputfile, $sorthphonoutputfile) = @_;
    my (%horthphonold,
	%horthphonnew,
	$key,
	@keys,
	$nReturnValue1,
	$slineorthphon,
	$linecounter,
	$changedcounter,
	$index,
	$entry,
	$hashsize,
	$db1,
	$dbout,
	$stransformed,
	);

    print "Changing further orthography.\n"; 

    $db1 = tie (%horthphonold, 'MLDBM', "$sorthphoninputfile", O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $sorthphoninputfile";
    Dumper($db1->{DB});
    $db1->{DB}->Filter_Push('utf8');

    $dbout = tie (%horthphonnew, 'MLDBM', "$sorthphonoutputfile",  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($dbout->{DB});
    $dbout->{DB}->Filter_Push('utf8');
    $linecounter = 0;
    $changedcounter = 0;

    @keys = natkeysort { $_} keys %horthphonold;

    foreach $key (@keys)
    {
#	print "$key\n";
	$linecounter++;
	$slineorthphon = $horthphonold{$key};
	
        $stransformed = $slineorthphon;
	
	$stransformed =~ s/abgesaegt/abgesagt/g; 
	$stransformed =~ s/aecht/acht/g; 
	$stransformed =~ s/aetz/ätz/g; 
	$stransformed =~ s/ausfaellend/ausfallend/g; 
	$stransformed =~ s/beschraenkt/beschränkt/g; 
	$stransformed =~ s/bestaenden/bestanden/g; 
	$stransformed =~ s/binaer/binär/g; 
	$stransformed =~ s/daempf/dampf/g; 
	$stransformed =~ s/disziplinaer/disziplinär/g;
	$stransformed =~ s/entspaennt/entspannt/g;
	$stransformed =~ s/faehrt/fahrt/g;
	$stransformed =~ s/faell/fall/g;
	$stransformed =~ s/geschaemt/geschämt/g;
 	$stransformed =~ s/gestaenden/gestanden/g;
	$stransformed =~ s/gewaegt/gewagt/g;
	$stransformed =~ s/gewaeltig/gewaltig/g;  
	$stransformed =~ s/glaenz/glänz/g;
	$stransformed =~ s/haelt/halt/g; 
	$stransformed =~ s/itaer/itär/g;  
	$stransformed =~ s/itaet/ität/g; 
	$stransformed =~ s/haeng/häng/g; 
	$stransformed =~ s/jaehr/jähr/g; 
	$stransformed =~ s/jaemmerlich/jämmerlich/g; 
	$stransformed =~ s/kaemm/kämm/g; 
	$stransformed =~ s/kaempf/kämpf/g; 
	$stransformed =~ s/kraenz/kränz/g; 
	$stransformed =~ s/laepper/läpper/g; 
	$stransformed =~ s/laestig/last+ig/g; 
	$stransformed =~ s/naehr/nähr/g; 
 	$stransformed =~ s/populaer/populär/g;
	$stransformed =~ s/raech/räch/g;
	$stransformed =~ s/raeum/räum/g;
	$stransformed =~ s/saeug/saug/g;
	$stransformed =~ s/schael/schäl/g;
	$stransformed =~ s/schaeum/schäum/g;
	$stransformed =~ s/schwaerm/schwärm/g; 
	$stransformed =~ s/sekundaer/sekundär/g;
	$stransformed =~ s/singulaer/singulär/g; 
	$stransformed =~ s/spaen/spän/g;
	$stransformed =~ s/subsidiaer/subsidiär/g; 
	$stransformed =~ s/staerk/stark/g;
	$stransformed =~ s/staeub/stäub/g;
	$stransformed =~ s/taendel/tändel/g; 
	$stransformed =~ s/waehl/wähl/g;
	$stransformed =~ s/waert/wärt/g;
	$stransformed =~ s/waelz/wälz/g;
 	$stransformed =~ s/zaehl/zähl/g;
 	$stransformed =~ s/zaehm/zähm/g;
	$stransformed =~ s/zirkulaer/zirkulär/g; 
 	$stransformed =~ s/zwaeng/zwäng/g;
	$stransformed =~ s/Faehre/Fähre/g;
 	$stransformed =~ s/Kaeufen/kaufen/g;
	$stransformed =~ s/Militaer/Militär/g;
 	$stransformed =~ s/Saegen/Sagen/g; 
	$stransformed =~ s/Saeuger/Sauger/g; 
	$stransformed =~ s/Schwaer/Schwär/g; 
	$stransformed =~ s/Sekretaer/Sekretär/g; 
	$stransformed =~ s/Staende/Stande/g; 
	$stransformed =~ s/Staette/Stätte/g; 
	$stransformed =~ s/\(aer\)/\(är\)/g; 
	$stransformed =~ s/\(aet\)/\(ät\)/g; 
	$stransformed =~ s/besoeffen/besoffen/g; 
	$stransformed =~ s/boese/böse/g; 
	$stransformed =~ s/floeh/flöh/g; 
	$stransformed =~ s/generoes/generös/g; 
	$stransformed =~ s/gewoehn/gewöhn/g;
	$stransformed =~ s/gefroeren/gefroren/g;  
	$stransformed =~ s/goenn/gönn/g; 
	$stransformed =~ s/hoehn/höhn/g; 
	$stransformed =~ s/ingenioes/ingeniös/g; 
	$stransformed =~ s/loegen/logen/g; 
	$stransformed =~ s/religioes/religiös/g; 
	$stransformed =~ s/roest/rost/g; 
	$stransformed =~ s/schoen/schon/g; 
	$stransformed =~ s/schwoer/schwör/g;
	$stransformed =~ s/soennt/sonnt/g;  
	$stransformed =~ s/soetten/sotten/g;
	$stransformed =~ s/stroem/ström/g; 
	$stransformed =~ s/stroes/strös/g; 
	$stransformed =~ s/varikoes/varikös/g; 
	$stransformed =~ s/verboegen/verbogen/g; 
	$stransformed =~ s/verboeten/verboten/g; 
	$stransformed =~ s/vergoeren/vergoren/g; 
	$stransformed =~ s/stoehlen/stohlen/g; 
	$stransformed =~ s/verloegen/verlogen/g; 
	$stransformed =~ s/verfloessen/verflossen/g; 
	$stransformed =~ s/versoeffen/versoffen/g; 
	$stransformed =~ s/überhoeben/überhoben/g;
	$stransformed =~ s/Moehre/Möhre/g;
	$stransformed =~ s/Poekel/Pökel/g;
	$stransformed =~ s/Adreße/Adresse/g;
	$stransformed =~ s/Waßer/Wasser/g;
	$stransformed =~ s/droßel/drossel/g;
	$stransformed =~ s/Droßel/Drossel/g;
	$stransformed =~ s/Taße/Tasse/g;
 	$stransformed =~ s/serioes/seriös/g; 
	$stransformed =~ s/\(oes\)/\(ös\)/g; 
	$stransformed =~ s/\(ioes\)/\(iös\)/g; 
	$stransformed =~ s/bruet/brüt/g;
	$stransformed =~ s/bue\ß/bü\ß/g;
	$stransformed =~ s/drueck/drück/g;  
	$stransformed =~ s/duerf/dürf/g; 
	$stransformed =~ s/duerr/dürr/g; 
	$stransformed =~ s/duester/düster/g;
	$stransformed =~ s/fliess/flie\ß/g;
	$stransformed =~ s/fluecht/flücht/g;
	$stransformed =~ s/fueg/füg/g;  
	$stransformed =~ s/fuehr/führ/g; 
	$stransformed =~ s/fuetter/fütter/g; 
	$stransformed =~ s/genueg/genüg/g; 
	$stransformed =~ s/gueltig/gültig/g;
 	$stransformed =~ s/ha\ß/hass/g;
	$stransformed =~ s/huet/hüt/g; 
	$stransformed =~ s/kuend/künd/g; 
	$stransformed =~ s/kuerz/kürz/g;
	$stransformed =~ s/ruede/rüde/g;  
	$stransformed =~ s/ruehr/rühr/g;  
	$stransformed =~ s/schmueck/schmück/g;
	$stransformed =~ s/stuerm/stürm/g;  
	$stransformed =~ s/stuerz/stürz/g; 
	$stransformed =~ s/stuetz/stutz/g; 
	$stransformed =~ s/truebe/trübe/g;
	$stransformed =~ s/trueg/trüg/g;
	$stransformed =~ s/wuensch/wünsch/g;
	$stransformed =~ s/wuerz/würz/g;
	$stransformed =~ s/zuecht/zücht/g;
	$stransformed =~ s/zuend/zünd/g;
	$stransformed =~ s/Blueten/Bluten/g;
	$stransformed =~ s/Fuss/Fu\ß/g;
	$stransformed =~ s/Gemuet/Gemüt/g;
 	$stransformed =~ s/Hass/Haß/g;
	$stransformed =~ s/Kalkuel/Kalkül/g; 
	$stransformed =~ s/Riss/Riß/g; 
	$stransformed =~ s/Ross/Roß/g; 
	$stransformed =~ s/schluepf/schlüpf/g; 
	$stransformed =~ s/Molekuel/Molekül/g; 
	$stransformed =~ s/Wuerze/Würze/g;
	$stransformed =~ s/\(Prozess\)/\(Prozeß\)/g; 
	$stransformed =~ s/\\Prozess\+/\\Prozeß\+/g; 
	$stransformed =~ s/schuss\+/schuß\+/g; 
	$stransformed =~ s/schuss\\/schuß\\/g; 
	$stransformed =~ s/\(Ablass\)/\(Ablaß\)/g; 
	$stransformed =~ s/\(blass\)/\(blaß\)/g; 
	$stransformed =~ s/\+blass\\/\+blaß\\/g;
 	$stransformed =~ s/\\blass\+/\\blaß\+/g;
	$stransformed =~ s/fluss/fluß/g;
 	$stransformed =~ s/\\blass\+/\\blaß\+/g;
	$stransformed =~ s/\(laß\)\[V/\(lass\)\[V/g; 
	$stransformed =~ s/\(paß\)/\(pass\)/g; 
	$stransformed =~ s/\\paß\+/\\pass\+/g; 
	$stransformed =~ s/lueg/lug/g; 
	$stransformed =~ s/mue\ß/müss/g; 
	$stransformed =~ s/schiess/schie\ß/g;
	$stransformed =~ s/schliess/schlie\ß/g;
	$stransformed =~ s/schmeiss/schmei\ß/g;


   	$horthphonnew{$key} = $stransformed;
	if ($stransformed ne $slineorthphon)
	{
	    $changedcounter++;
	}
    }
    $hashsize = keys %horthphonnew;
    undef $db1;
    undef $dbout;
    untie (%horthphonold);
    untie (%horthphonnew);

    print "valid lines of inputfile: $linecounter , changed: $changedcounter , number of entries in hash: $hashsize\n";
    return ($sorthphonoutputfile);
}

####

sub change_to_new_orthography 
{
    my ($sorthmorphinputfile, $sorthmorphoutputfile) = @_;
    my (%horthmorphold,
	%horthmorphnew,
	$key,
	@keys,
	$nReturnValue1,
	$slineorthmorph,
	$linecounter,
	$changedcounter,
	$index,
	$entry,
	$hashsize,
	$db1,
	$dbout,
	$stransformed,
	$candidateforconsonantrule,
	$candidatesfile,
	$morphword,
	);

    print "\nTransfer to new spelling.\n";

    $db1 = tie (%horthmorphold, 'MLDBM', "$sorthmorphinputfile", O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $sorthmorphinputfile";
    Dumper($db1->{DB});
    $db1->{DB}->Filter_Push('utf8');

    $dbout = tie (%horthmorphnew, 'MLDBM', "$sorthmorphoutputfile",  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($dbout->{DB});
    $dbout->{DB}->Filter_Push('utf8');
    $linecounter = 0;
    $changedcounter = 0;

    $candidatesfile = "Doubleconsonants";
    if(-e $candidatesfile) 
    {
	unlink $candidatesfile;
    }

    @keys = natkeysort { $_} keys %horthmorphold;

    print "\nRepairing some flaws of the database.\n";


    foreach $key (@keys)
    {

	$linecounter++;
	$slineorthmorph = $horthmorphold{$key};
#	print "$key $slineorthmorph\n";
	$stransformed = $slineorthmorph;
	$stransformed =~ s/bzeß/bzess/g; 
	$stransformed =~ s/baß/bass/g; 
	$stransformed =~ s/Baß/Bass/g; 
	$stransformed =~ s/bewußt/bewusst/g; 
	$stransformed =~ s/Bewußt/Bewusst/g; 
	$stransformed =~ s/biß/biss/g; 
	$stransformed =~ s/Biß/Biss/g; 
	$stransformed =~ s/blaß/blass/g;
 	$stransformed =~ s/la\ß/lass/g;
 	$stransformed =~ s/lä\ß/läss/g;
	$stransformed =~ s/boß/boss/g; 
	$stransformed =~ s/Boß/Boss/g; 
	$stransformed =~ s/Geschoß/Geschoss/g; 
	$stransformed =~ s/geschoß/geschoss/g; 
	$stransformed =~ s/daß/dass/g; 
	$stransformed =~ s/faß/fass/g; 
	$stransformed =~ s/Faß/Fass/g; 
	$stransformed =~ s/fluß/fluss/g; 
	$stransformed =~ s/Fluß/Fluss/g; 
	$stransformed =~ s/guß/guss/g; 
	$stransformed =~ s/Guß/Guss/g; 
	$stransformed =~ s/Haß/Hass/g; 
	$stransformed =~ s/Jaß/Jass/g; 
	$stransformed =~ s/kuß/kuss/g; 
	$stransformed =~ s/Kuß/Kuss/g; 
	$stransformed =~ s/Küß/Küss/g; 
	$stransformed =~ s/miß/miss/g; 
	$stransformed =~ s/Miß/Miss/g; 
	$stransformed =~ s/meß/mess/g; 
	$stransformed =~ s/Meß/Mess/g; 
	$stransformed =~ s/naß/nass/g; 
	$stransformed =~ s/Naß/Nass/g; 
	$stransformed =~ s/nuß/nuss/g; 
	$stransformed =~ s/Nuß/Nuss/g; 
	$stransformed =~ s/Nüß/Nüss/g; 
	$stransformed =~ s/nüß/nüss/g; 
	$stransformed =~ s/Paß/Pass/g; 
	$stransformed =~ s/([^s|S])paß/$1pass/g; #delimiters because of Spaß 
	$stransformed =~ s/([^s|S])paß/$1pass/g; #delimiters because of Spaß 
	$stransformed =~ s/^paß/pass/g; #delimiters because of Spaß 
	$stransformed =~ s/Prozeß/Prozess/g; 
#	$stransformed =~ s/Prinzeß/Prinzess/g; 
	$stransformed =~ s/prozeß/prozess/g; 
	$stransformed =~ s/expreß/express/g; 
	$stransformed =~ s/Expreß/Express/g; 
	$stransformed =~ s/zeß/zess/g; 
	$stransformed =~ s/freß/fress/g; 
	$stransformed =~ s/Freß/Fress/g; 
	$stransformed =~ s/preß/press/g; 
	$stransformed =~ s/Preß/Press/g; 
	$stransformed =~ s/gewiß/gewiss/g; 
	$stransformed =~ s/Gewiß/Gewiss/g; 
	$stransformed =~ s/gräßlich/grässlich/g; 
	$stransformed =~ s/Gräßlich/Grässlich/g; 
	$stransformed =~ s/häßlich/hässlich/g; 
	$stransformed =~ s/Häßlich/hässlich/g; 
	$stransformed =~ s/näßlich/nässlich/g; 
	$stransformed =~ s/unpäß/unpäss/g; 
	$stransformed =~ s/Unpäß/Unpäss/g; 
	$stransformed =~ s/wiß/wiss/g; 
	$stransformed =~ s/Wiß/Wiss/g; 
	$stransformed =~ s/neß/ness/g; 
	$stransformed =~ s/\(eß\)/\(ess\)/g; 
	$stransformed =~ s/\+eß\\/\+ess\\/g; 
	$stransformed =~ s/riß/riss/g; 
	$stransformed =~ s/Riß/Riss/g; 
	$stransformed =~ s/Roß/Ross/g;
	$stransformed =~ s/Röß/Röss/g;
	$stransformed =~ s/Walroß/Walross/g; 
	$stransformed =~ s/proß/pross/g; 
	$stransformed =~ s/pröß/pröss/g;
	$stransformed =~ s/schiß/schiss/g; 
	$stransformed =~ s/Schiß/Schiss/g;
	$stransformed =~ s/schuß/schuss/g; 
	$stransformed =~ s/Schuß/Schuss/g; 
	$stransformed =~ s/schloß/schloss/g; 
	$stransformed =~ s/Schloß/Schloss/g; 
	$stransformed =~ s/schlöß/schlöss/g; 
	$stransformed =~ s/Schlöß/Schlöss/g; 
	$stransformed =~ s/schluß/schluss/g; 
	$stransformed =~ s/Schluß/Schluss/g; 
	$stransformed =~ s/Streß/Stress/g; 
	$stransformed =~ s/streß/stress/g; 
	$stransformed =~ s/Eß/Ess/g; 
	$stransformed =~ s/\\eß/\\ess/g;
	$stransformed =~ s/Piß/Piss/g;  
	$stransformed =~ s/reß/ress/g; 
	$stransformed =~ s/leß/less/g; 
	$stransformed =~ s/Täß/Täss/g; 
	
	$stransformed =~ s/allebendig/alllebendig/g;
	$stransformed =~ s/alliebend/allliebend/g;
	$stransformed =~ s/Ballettänzerin/Balletttänzerin/g;
	$stransformed =~ s/Bittag/Bitttag/g;
	#$stransformed =~ s/dennoch/dennnoch/g; wrong!
	#$stransformed =~ s/dennoch/dennnoch/g;
	#$stransformed =~ s/Drittel/Dritttel/g;
	$stransformed =~ s/helleuchtend/hellleuchtend/g;
	$stransformed =~ s/Kreppapier/Krepppapier/g;
	$stransformed =~ s/Kristallüster/Kristalllüster/g;
	$stransformed =~ s/Logglas/Loggglas/g;
	$stransformed =~ s/Nullinie/Nulllinie/g;
	$stransformed =~ s/programmäßig/programmmäßig/g;
	$stransformed =~ s/Raumschiffahrt/Raumschifffahrt/g;
	$stransformed =~ s/Rolladen/Rollladen/g;
	$stransformed =~ s/Schallehre/Schalllehre/g;
	$stransformed =~ s/Schalloch/Schallloch/g;
	$stransformed =~ s/Schiffahrt/Schifffahrt/g;
	$stransformed =~ s/Schnellaster/Schnelllaster/g;
	$stransformed =~ s/Schnellauf/Schnelllauf/g;
	$stransformed =~ s/Schnelläufer/Schnellläufer/g;
	$stransformed =~ s/schnellebig/schnelllebig/g;
	$stransformed =~ s/Schwimmeister/Schwimmmeister/g;
	$stransformed =~ s/Sperrad/Sperrrad/g;
	$stransformed =~ s/Sperriegel/Sperrriegel/g;
	$stransformed =~ s/Stallaterne/Stalllaterne/g;
	$stransformed =~ s/Stammannschaft/Stammmannschaft/g;
	$stransformed =~ s/Stammiete/Stammmiete/g;
	$stransformed =~ s/Stammutter/Stammmutter/g;
	$stransformed =~ s/Stemmeißel/Stemmmeißel/g;
	$stransformed =~ s/stickstoffrei/stickstofffrei/g;
	$stransformed =~ s/Stilleben/Stillleben/g;
	$stransformed =~ s/stillegen/stilllegen/g;
	$stransformed =~ s/Stoffetzen/Stofffetzen/g;
	$stransformed =~ s/volladen/vollladen/g;
	$stransformed =~ s/vollaufen/volllaufen/g;
	$stransformed =~ s/Wetteufel/Wettteufel/g;
	$stransformed =~ s/Wetturnen/Wettturnen/g;
	$stransformed =~ s/wetturnend/wettturnend/g;
	$stransformed =~ s/Zollinie/Zolllinie/g;


# result of candidate search of second cycle
# if uncommented these rules would be produced
# for the file Doubleconsonants

	$stransformed =~ s/Eisschnellauf/Eisschnelllauf/g;
	$stransformed =~ s/Flussschiffahrt/Flussschifffahrt/g;
	$stransformed =~ s/Küstenschiffahrt/Küstenschifffahrt/g;
	$stransformed =~ s/Luftschiffahrt/Luftschifffahrt/g;

## Furthermore:

	$stransformed =~ s/Zäheit/Zähheit/g;

	
	### some mistakes in the database

	#bring back the men, make them nouns again. Ok, there is Trump, but that is no reason, because 99,999% of them are decent.
	
	$stransformed =~ s/^(.*?)(\+mann\\)x(\\.*?)\(mann\)\[\]\)(\[V\].*?)$/$1$2xV$3\(Mann\)\[N\]\)$4/g; # first the verbs
	$stransformed =~ s/^(.*?)(\+mann\\)(N|F|B|V|P|A|x)(\\.*?)\(mann\)\[\]\)(.*?)$/$1$2$3N$4\(Mann\)\[N\]\)$5/g; # single letters	
	$stransformed =~ s/^(.*?)(\+mann\\)(N|V)x(\\.*?)\(mann\)\[\]\)(.*?)$/$1$2$3xN$4\(Mann\)\[N\]\)$5/g;
	# at begin of word change first letter
	$stransformed =~ s/^(.*?)mann(\+.*\\)(x.*?)(\\.*)\(mann\)\[\](.*?)$/$1Mann$2N$3$4\(Mann\)\[N\]$5/g;
   # and all subconstituents
	$stransformed =~ s/\(mann\)\[\]/\(Mann\)\[N\]/g;

	#Other cases with missing PoS categories: Immobilienhändler, Rest, Klassizismus, Kenntnisnahme etc. 
	
	$stransformed =~ s/(.*?\\)immobilien(\+.*?\\)(.+?)(\\.*?)\(immobilien\)\[\](.*?)/$1Immobilien$2N$3$4\(Immobilien\)\[N\]$5/g;

	# Kenntnisnahme same as Maßnahme, Rücksichtnahme
	$stransformed =~ s/(.*?Kenntnisnahme\\.+?\\)C(\\.*?\\)Kenntnis\+nahme\\N(\\.+?)\(nahme\)\[\](.*?)/$1Z$2kenntnisnehm\\V$3\(nehm\)\[V\]\)\[V\]$4/;


	$stransformed =~ s/(.*?\\klass)(\+.*?\\)(.+?)(\\.*?)\(klass\)\[\](.*?)/$1$2R$3$4\(klass\)\[R\]$5/g;
	$stransformed =~ s/\(klass\)\[\]/\(klass\)\[R\]/g;

	# kopflastig analysis as warmherzig, also no umlaut
	
	$stransformed =~ s/(.*?Kopf\+)l(ast\+ig\\NA)(\\.+?)\(\(Last\)\[N\]\,\(ig\)\[A\|N\.\]\)\[A\]\)(.*?)N\\Y\\N(.*?)/$1L$2x$3\(Last\)\[N\]\,\(ig\)\[A\|AN\.\]\)$4N\\N\\N$5/;

	$stransformed =~ s/(.*?\\schraff)(\+.*?\\)(.+?)(\\.*?)\(schraff\)\[\](.*?)/$1$2R$3$4\(schraff\)\[R\]$5/g;
	$stransformed =~ s/\(schraff\)\[\]/\(schraff\)\[R\]/g;
	
	$stransformed =~ s/(.*?\\)rest(\+.*?\\)(.+?)(\\.*?)\(rest\)\[\](.*?)/$1Rest$2N$3$4\(Rest\)\[N\]$5/g;
	$stransformed =~ s/(.*?\+)rest(\\.+?)(\\.*?)\(rest\)\[\](.*?)/$1Rest$2N$3\(Rest\)\[N\]$4/g;

# Sohlengänger same structure as Fußgänger, Rutengänger the structure with "gang" as adjective is wrong

	$stransformed =~ s/(.*?)(Sohlengänger)(.*)Sohle\+n\+gang\+er\\NxAx(\\.*?)\(\(Sohle\).+\[N\](.*)/$1$2$3Sohle\+n\+Gang\+er\\NxNx$4\(\(Sohle\)\[N\]\,\(n\)\[N\|N\.Nx\]\,\(\(geh\)\[V\]\)\[N\]\,\(er\)\[N\|NxN\.\]\)\[N\]$5/g;

	
	$stransformed =~ s/^zinken\\1\\Z\\1\\Y\\Y\\Y\\zinken\\N\\N\\N\\N\\\(\(zinken\)\[N\]\)/zinken\\1\\Z\\1\\Y\\Y\\Y\\Zink\\N\\N\\N\\N\\\(\(Zink\)\[N\]\)/g;
	
	$stransformed =~ s/^verzinken\\6\\C\\1\\Y\\Y\\Y\\ver\+zink\\xV\\N\\N\\N\\\(\(ver\)\[V\|\.V\]\,\(\(zinken\)\[N\]\)\[V\]\)\[V\]/verzinken\\6\\C\\1\\Y\\Y\\Y\\ver\+zink\\xV\\N\\N\\N\\\(\(ver\)\[V\|\.V\]\,\(\(Zink\)\[N\]\)\[V\]\)\[V\]/;



	
	$candidateforconsonantrule = consonantrule_suspicious($stransformed);
	if ($candidateforconsonantrule)
	{
	    $stransformed =~ /^(.*?)\\.*$/;
	    $morphword = $1;
#	  print "$morphword\#$candidateforconsonantrule\n";
	    open (AUSGABE, ">>$candidatesfile") || die "Cannot open checkfile! ";
	    print AUSGABE "\$stransformed \=\~ s/$morphword/$candidateforconsonantrule/g\;\n";
	}

   	$horthmorphnew{$key} = $stransformed;

	if ($stransformed ne $slineorthmorph)
	{
	    $changedcounter++;
	}
#    	    print ".";
    }
    $hashsize = keys %horthmorphnew;
    undef $db1;
    undef $dbout;
    untie (%horthmorphold);
    untie (%horthmorphnew);
    print "\nvalid lines of inputfile: $linecounter , changed: $changedcounter , number of entries in hash: $hashsize\n";
    return ($sorthmorphoutputfile);
}

sub consonantrule_suspicious {
    my ($stransformed) = @_;
    my ($transformed,
	$lemma,
	$oldlemma,
	$lower_lemma,
	@lower_lemma,
	$llchar,
	$ics,
	$consonants,
#	$c,
	$lower_ics,
#	@lower_ics,
	$element,
	$lichar,
	$last,
	$before_last,
	$bbl,
	$concatenated_ics,
	$find,
	$replace,
	);

    $consonants = "bcdfghjklmnpqrstvwxz";
    $transformed = $stransformed;
  #  print "$transformed\n";


    $transformed =~ /^([^\\]*)\\[^\\]*\\[^\\]*\\[^\\]*\\[^\\]*\\[^\\]*\\[^\\]*\\([^\\]*)\\.*$/;
    $lemma = $1;  
    $oldlemma = $1;
    $lower_lemma = lc($lemma);
    $ics = $2;
    $ics =~ s/\+//g;
    
    $lower_ics = lc($ics);
 #   print "$lower_ics\n";

# if double consonant in lemma and there is a different between ics and lemma 

 #   @lower_ics = split //, $lower_ics;
    @lower_lemma = split //, $lower_lemma;
    
    $last = "";
    $before_last = "";
    $bbl = "";
    
    while ($element = shift(@lower_lemma) )
    {
	if (($last =~   /([$consonants])/) && ($before_last eq $1) && ($bbl ne $1) && ($element ne $1) && ($lower_ics =~ /$1$1$1/) )
	{
	 #   print "$lower_lemma\n";
	    $find = $last . $last;
	    $find = quotemeta $find; 
	    $replace = $last . $last . $last;
	  #  print "$find $replace\n";
	    $lemma =~ s/$find/$replace/g;
	   # print "$lemma\n";
	}
	$bbl = $before_last;
	$before_last = $last;
	$last = $element;
#	# create new spelling form
    }
    if ($oldlemma ne $lemma)
    {
	return $lemma; # suspicious
    }
    else 
    {
	return 0;
    }
}


sub change_phons_tosurface {
    my ($sphoninputfile, $sortphonoutputfile) = @_;
    my ($db1,
	$dbout,
	%hphon,
	%horthphonsurface,
	$linecounter,
	$unchangedcounter,
	$checkfile,
	@keys,
	$key,
	$sLinephon,
	$sLinephoncopy1,
	$sLinephoncopy2,
	$lemma,
	$letterbefore,
	$vowel,
	$letterafter,
	$newletterafter,
	$newletterbefore,
	$delim,
	$before,
	$PhonSylStBCLX,
	$PhonSylStBCLXwithoutbrackets,
	$between,
	$PhonolSAM,
	$PhonolSAMold,
	$PhonolCLX,
	$oePhonolSAM,
	$PhonolSAMwithoutdel,	
	$PhonolCLXwithoutdel,
	$stransformed,
	$stransformeddel,
	$stransformeddelwoschwa,
	$stransformeddelshortvowel,
	$stransformeddelwoschwashortvowel,
	$hashsize,
	);

 my %hvoicedvoiceless = (
     'g' => 'k',
     'b' => 'p',
     'z' => 's',
     'd' => 't',
     );

     my %hoePhonolSAM = (
     'Q' => '/',
     '&' => '|',
        );
    
    print "\nCreate data with surface phonemes\n";
    $db1 = tie (%hphon, 'MLDBM', "$sphoninputfile", O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $sphoninputfile";
    Dumper($db1->{DB});
    $db1->{DB}->Filter_Push('utf8');
    
    $dbout = tie (%horthphonsurface, 'MLDBM', "$sortphonoutputfile",  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($dbout->{DB});
    $dbout->{DB}->Filter_Push('utf8');
    $linecounter = 0;
    $unchangedcounter = 0;
    $checkfile = "Checkfile2";
    if(-e $checkfile) 
    {
	unlink $checkfile;
    }
    @keys = natkeysort { $_} keys %hphon;
    KEY: foreach $key (@keys)
	{
	    # print "$key\n";
	    $delim = "dummy";
	    $linecounter++;
	    $sLinephon = $hphon{$key};
	  #  print "sLinephon: $sLinephon\n";
	    $sLinephoncopy1 = $sLinephon;
	   # print "copy1:  $sLinephoncopy1\n";
	    $sLinephoncopy2 = $sLinephon; # changes will be done here

	    # get the fields of interest
	    if ($sLinephon =~ /^(.*)(\\.*\\.*\\.*\\.*\\)([^\\]+)(\\.*\\.*)\\([^\\]+)\\([^\\]+)$/ )
	    {
		$lemma = $1;
		$before = $2;
		$PhonSylStBCLX = $3;
	#	print "Ph: $PhonSylStBCLX\n";
		$between = $4;
		$PhonolSAM = $5;
	#	print "SAM: $PhonolSAM\n";
		$PhonolSAMold = $PhonolSAM; 
		$PhonolCLX = $6;
		# and check if they are equal
		$PhonSylStBCLXwithoutbrackets = $PhonSylStBCLX;
		$PhonSylStBCLXwithoutbrackets =~ s/[\[\]]//g;
		# print "wob: $PhonSylStBCLXwithoutbrackets\n";
		$PhonolSAMwithoutdel = $PhonolSAM;
		$PhonolCLXwithoutdel = $PhonolCLX;
		$PhonolSAMwithoutdel =~ s/[\#\+]//g;
		$PhonolCLXwithoutdel =~ s/[\#\+]//g;
		#print "wo: $PhonolSAMwithoutdel\n";
		#print "wo: $PhonolCLXwithoutdel\n";
		# if yes just add to output
		
		if (($PhonolSAMwithoutdel eq $PhonSylStBCLXwithoutbrackets) or ($PhonolCLXwithoutdel eq $PhonSylStBCLXwithoutbrackets))
		{
		    $horthphonsurface{$key} = $sLinephoncopy1;
		    $unchangedcounter++;
		}
		# now the exceptions
	
		else
		{
		    # Auslautverhaertung
		    $stransformed = $PhonSylStBCLXwithoutbrackets;
		    $stransformed =~ s/t$/d/;
		    $stransformed =~ s/s$/z/;
		    $stransformed =~ s/Ig$/Ix/;
		    $stransformed =~ s/k$/g/;
		    $stransformed =~ s/p$/b/;
		    $stransformed =~ s/f$/v/;

		    #		    $stransformeddel = $PhonolSAM;
		    $stransformeddel = $PhonolCLX;
		    $stransformeddel =~ s/d#/t/g;
		    $stransformeddel =~ s/z#/s/g;
		    $stransformeddel =~ s/Ig#/Ix/g;
		    $stransformeddel =~ s/g#/k/g;
		    $stransformeddel =~ s/b#/p/g;
		    $stransformeddel =~ s/v#/f/g;
		    
		    $stransformeddel =~ s/b\+s/p\+s/g; #erwerbs
		    $stransformeddel =~ s/d\+s/t\+s/g; #bords
		    $stransformeddel =~ s/g\+s/k\+s/g; #tags
		   #  $stransformeddel =~ s/v\+s/f\+s/g; #
		    
		    $stransformeddel =~ s/Ig\+/Ix/g;
		    
		    $stransformeddel =~ s/d$/t/;
		    $stransformeddel =~ s/z$/s/;
		    $stransformeddel =~ s/Ig$/Ix/;
		    $stransformeddel =~ s/g$/k/;
		    $stransformeddel =~ s/b$/p/;
		   		    
		    
		    $stransformeddelwoschwa = $stransformeddel;
		 #   print "Start $stransformeddelwoschwa\n";

		    #first some non-schwas
		    $stransformeddelwoschwa =~ s/a:\+(E:?)([rlt])/\+$1$2/g; # konträr, Rosette
		    
		 
		    $stransformeddelwoschwa =~ s/([^\\\#]{2,})\@\#/$1\#/g; # at least two letters before (exclude #b@# and #g@#)
		    
		    $stransformeddelwoschwa =~ s/\+\#/\#/g;

		    $stransformeddelwoschwa =~ s/\@\+(?!n\#)/\+/g; # amusisch, einfarbig, erst(e);
		                                                      #  not e+n (Fuge, interfix)

		 
		    $stransformeddelwoschwa =~ s/t\+\+n/t\+\@\+n/g; # not t+e+n
		    $stransformeddelwoschwa =~ s/g\+\+n/g\+\@\+n/g; # not g+e+n

		    
		    $stransformeddelwoschwa =~ s/\@l\+/l\+/g; # Entwicklung
		    $stransformeddelwoschwa =~ s/\@n\+(?!\@$)/n\+/g; # Zeichnung, not +e+n+e$ (Erstgeborene)
		    $stransformeddelwoschwa =~ s/\@n$/n/g; # überzeichnen

		    $stransformeddelwoschwa =~ s/\@n#n/#n\+/g; # verzeichnis 
		    
		    $stransformeddelwoschwa =~ s/([^\+])\@r\+([^s])/$1r\+$2/g; # poltrig, exclude anders and +er+
		    
		    # and then again Habseligkeit b -> p
		    $stransformeddelwoschwa =~ s/d#/t/g;
		    $stransformeddelwoschwa =~ s/z#/s/g;
		    $stransformeddelwoschwa =~ s/Ig#/Ix/g;
		    #$stransformeddelwoschwa =~ s/Ix#/Ig/g;
		    $stransformeddelwoschwa =~ s/g#/k/g;
		    $stransformeddelwoschwa =~ s/b#/p/g;
		    $stransformeddelwoschwa =~ s/v#/f/g;

		    $stransformeddelwoschwa =~ s/\+\+/\+/g;

		    $stransformeddelwoschwa =~ s/b\+s/p\+s/g; #gewebs
		    $stransformeddelwoschwa =~ s/d\+s/t\+s/g; #sonnabends
		    $stransformeddelwoschwa =~ s/g\+s/k\+s/g; # ?
		    $stransformeddelwoschwa =~ s/v\+s/f\+s/g; # ?

		   # $stransformeddelwoschwa =~ s/g\+\@\+n/k\+\@\+n/g; # ? schlacke with recovered @

		    
		    #$stransformeddelwoschwa =~ s/Ig\+/Ix/g;
		    $stransformeddelwoschwa =~ s/\+Ix\+/Ig/g;
		    $stransformeddelwoschwa =~ s/tIx\+/tIg/g; # Leibhaftige

		    
		    $stransformeddel =~ s/\+//g; 
		    $stransformeddel =~ s/\#//g;

		    $stransformeddelwoschwa =~ s/\+//g;
		    $stransformeddelwoschwa =~ s/\#//g;

		   # print "zw transformeddelwoschwa:  $stransformeddelwoschwa\n";
		    
		   # print "transformed:  $stransformed , tranformeddel: $stransformeddel ,
		#	   wo: $PhonolCLXwithoutdel , wob: $PhonSylStBCLXwithoutbrackets \n";
		   		    		    
		    
		    if ($stransformed eq $PhonolCLXwithoutdel)
		    {
		#	print "1 Auslautverhärtung: $stransformed\n";
			#	$horthphonsurface{$key} = $sLinephoncopy1;
			$PhonolSAM =~ s/d$/t/;
			$PhonolSAM =~ s/z$/s/;
			$PhonolSAM =~ s/Ig$/Ix/;
			$PhonolSAM =~ s/g$/k/;
			$PhonolSAM =~ s/b$/p/;
			$PhonolSAM =~ s/v$/f/;

			$PhonolCLX =~ s/d$/t/;
			$PhonolCLX =~ s/z$/s/;
			$PhonolCLX =~ s/Ig$/Ix/;
			$PhonolCLX =~ s/g$/k/;
			$PhonolCLX =~ s/b$/p/;
			$PhonolCLX =~ s/v$/f/;
			
			$sLinephoncopy2 = "$lemma$before$PhonSylStBCLX$between\\$PhonolSAM\\$PhonolCLX";
			$horthphonsurface{$key} = $sLinephoncopy2;			
			$unchangedcounter++;
			next KEY;
		    }
				    
		    if ($stransformeddel eq $PhonSylStBCLXwithoutbrackets)
		    {
		#	print "2 Auslautverhärtung: $stransformed\n";
			$PhonolSAM =~ s/d#/t#/g;
			$PhonolSAM =~ s/z#/s#/g;
			$PhonolSAM =~ s/Ig#/Ix#/g;
			$PhonolSAM =~ s/g#/k#/g;
			$PhonolSAM =~ s/b#/p#/g;
			$PhonolSAM =~ s/v#/f#/g;
			$PhonolCLX =~ s/d#/t#/g;
			$PhonolCLX =~ s/z#/s#/g;
			$PhonolCLX =~ s/Ig#/Ix#/g;
			$PhonolCLX =~ s/g#/k#/g;
			$PhonolCLX =~ s/b#/p#/g;
			$PhonolCLX =~ s/v#/f#/g;

			$PhonolSAM =~ s/Ig\+/Ix\+/g;
			$PhonolCLX =~ s/Ig\+/Ix\+/g;


			$PhonolSAM =~ s/b\+s/p\+s/g;
			$PhonolCLX =~ s/b\+s/p\+s/g;

			$PhonolSAM =~ s/d\+s/t\+s/g;
			$PhonolCLX =~ s/d\+s/t\+s/g;

			$PhonolSAM =~ s/g\+s/k\+s/g;
			$PhonolCLX =~ s/g\+s/k\+s/g;

		#	$PhonolSAM =~ s/v\+s/f\+s/g;
		#	$PhonolCLX =~ s/v\+s/f\+s/g;

			
			$PhonolSAM =~ s/d$/t/;
			$PhonolSAM =~ s/z$/s/;
			$PhonolSAM =~ s/Ig$/Ix/;
			$PhonolSAM =~ s/g$/k/;
			$PhonolSAM =~ s/b$/p/;
			$PhonolSAM =~ s/v$/f/;
			$PhonolCLX =~ s/d$/t/;
			$PhonolCLX =~ s/z$/s/;
			$PhonolCLX =~ s/Ig$/Ix/;
			$PhonolCLX =~ s/g$/k/;
			$PhonolCLX =~ s/b$/p/;
			$PhonolCLX =~ s/v$/f/;
			

			$sLinephoncopy2 = "$lemma$before$PhonSylStBCLX$between\\$PhonolSAM\\$PhonolCLX";
			$horthphonsurface{$key} = $sLinephoncopy2;

		#	$unchangedcounter++;
			next KEY;
		    }

		    if ($stransformeddelwoschwa eq $PhonSylStBCLXwithoutbrackets)
		    {
		#	print "2 Schwa Auslautverhärtung: $stransformeddelwoschwa\n";
			#first some non-schwas
			$PhonolSAM =~ s/a:\+(E:?)([rlt])/\+$1$2/g; # konträr, Rosette
			$PhonolCLX =~ s/a:\+(E:?)([rlt])/\+$1$2/g; # konträr, Rosette
			
			$PhonolSAM =~ s/([^\\\#]{2,})\@#/$1#/g;
			$PhonolCLX =~ s/([^\\\#]{2,})\@#/$1#/g;

			$PhonolSAM =~ s/\+#/#/g;
			$PhonolCLX =~ s/\+#/#/g;

			$PhonolSAM =~ s/\@\+(?!n\#)/\+/g; # amusisch, einfarbig, wangig
			$PhonolCLX =~ s/\@\+(?!n\#)/\+/g; # amusisch, einfarbig

			$PhonolSAM =~ s/t\+\+n/t\+\@\+n/g; # not t+e+n
			$PhonolCLX =~ s/t\+\+n/t\+\@\+n/g; # not t+e+n

			$PhonolSAM =~ s/g\+\+n/g\+\@\+n/g; # not g+e+n
			$PhonolCLX =~ s/g\+\+n/g\+\@\+n/g; # not g+e+n

		#	$PhonolSAM =~ s/g\+\@\+n/k\+\@\+n/g; # ? schlacken
		#	$PhonolCLX =~ s/g\+\@\+n/k\+\@\+n/g; # ?
			
			$PhonolSAM =~ s/\@l\+/l\+/g; # Entwicklung
			$PhonolCLX =~ s/\@l\+/l\+/g; # Entwicklung

			$PhonolSAM =~ s/\@n\+(?!\@$)/n\+/g; # Zeichnung
			$PhonolCLX =~ s/\@n\+(?!\@$)/n\+/g; #
			
		#	print "zw  PhonolSAM  $PhonolSAM\n";

			$PhonolSAM =~ s/\@n$/n/g; # überzeichnen
			$PhonolCLX =~ s/\@n$/n/g; # überzeichnen

			$PhonolSAM =~ s/\@n#n/#n/g; # verzeichnis
			$PhonolCLX =~ s/\@n#n/#n/g; # verzeichnis 

			$PhonolSAM =~ s/([^\+])\@r\+([^s])/$1r\+$2/g; # polterig
			$PhonolCLX =~ s/([^\+])\@r\+([^s])/$1r\+$2/g; # polterig

			$PhonolSAM =~ s/\+\+/\+/g;
			$PhonolCLX =~ s/\+\+/\+/g;


		#	print "zw 2 PhonolSAM  $PhonolSAM\n";

			$PhonolSAM =~ s/d#/t#/g;
			$PhonolSAM =~ s/z#/s#/g;
			$PhonolSAM =~ s/Ig#/Ix#/g;
			$PhonolSAM =~ s/g#/k#/g;
			$PhonolSAM =~ s/b#/p#/g;
			$PhonolSAM =~ s/v#/f#/g;
			$PhonolCLX =~ s/d#/t#/g;
			$PhonolCLX =~ s/z#/s#/g;
			$PhonolCLX =~ s/Ig#/Ix#/g;
			$PhonolCLX =~ s/g#/k#/g;
			$PhonolCLX =~ s/b#/p#/g;
			$PhonolCLX =~ s/v#/f#/g;			
		
			#$PhonolSAM =~ s/Ig\+/Ix\+/g;
			#$PhonolCLX =~ s/Ig\+/Ix\+/g;#

			$PhonolSAM =~ s/([\+t])Ix\+/$1Ig\+/g;
			$PhonolCLX =~ s/([\+t])Ix\+/$1Ig\+/g;

			$PhonolSAM =~ s/g\+s/k\+s/g;
			$PhonolCLX =~ s/g\+s/k\+s/g;

			$PhonolSAM =~ s/b\+s/p\+s/g;
			$PhonolCLX =~ s/b\+s/p\+s/g;

			$PhonolSAM =~ s/d\+s/t\+s/g;
			$PhonolCLX =~ s/d\+s/t\+s/g;

			$PhonolSAM =~ s/v\+s/f\+s/g;
			$PhonolCLX =~ s/v\+s/f\+s/g;

			$PhonolSAM =~ s/d$/t/;
			$PhonolSAM =~ s/z$/s/;
			$PhonolSAM =~ s/Ig$/Ix/;
			$PhonolSAM =~ s/g$/k/;
			$PhonolSAM =~ s/b$/p/;
			$PhonolSAM =~ s/v$/f/;
			$PhonolCLX =~ s/d$/t/;
			$PhonolCLX =~ s/z$/s/;
			$PhonolCLX =~ s/Ig$/Ix/;
			$PhonolCLX =~ s/g$/k/;
			$PhonolCLX =~ s/b$/p/;
			$PhonolCLX =~ s/v$/f/;

			$sLinephoncopy2 = "$lemma$before$PhonSylStBCLX$between\\$PhonolSAM\\$PhonolCLX";
			$horthphonsurface{$key} = $sLinephoncopy2;

			$unchangedcounter++;
			next KEY;
		    }
		    
		    if ($stransformeddel eq $stransformed)
		    {
		#	print "3 Auslautverhärtung: $stransformed\n";
			$horthphonsurface{$key} = $sLinephoncopy1;
			$unchangedcounter++;
			next KEY;
		    }
### hier noch Sam -> CLX ??
		     if (("$stransformed\@" eq $PhonolCLXwithoutdel) or
			 ("$PhonSylStBCLXwithoutbrackets\@" eq $PhonolCLXwithoutdel) )
		    
		    {
		#	print "Schwa at the end: $PhonolCLXwithoutdel\n";
			$horthphonsurface{$key} = $sLinephoncopy1;
			$unchangedcounter++;
			next KEY;
		    }
		    
		    ## now changes
		    
		    
		    if (($lemma =~ /[Bb]lend/) && ($PhonSylStBCLXwithoutbrackets =~ /blEn([dt])/) )
		    {
			$letterafter = $1;
			$PhonolSAM =~ s/blInd/blEn${letterafter}/g;
			$PhonolCLX =~ s/blInd/blEn${letterafter}/g;
		    }
		    
		    
		    if ($lemma =~ /[Bb]rand/)
		    {
			$PhonolSAM =~ s/brEn/brand/g;
			$PhonolCLX =~ s/brEn/brand/g;
		    }

		    
		    if (($lemma =~ /[Bb][aä]nd/) && ($PhonSylStBCLXwithoutbrackets =~ /b([aE])n([dt])/) )
		    {
			$vowel = $1;
			$letterafter = $2;
			$PhonolSAM =~ s/bInd/b${vowel}n${letterafter}/g;
			$PhonolCLX =~ s/bInd/b${vowel}n${letterafter}/g;
		    }
		    
		    if (($lemma =~ /[bB]ogen/) && ($PhonSylStBCLXwithoutbrackets =~ /bo:g\@n/) )
		    {
			$PhonolSAM =~ s/bi:g/bo:g\@n/g;
			$PhonolCLX =~ s/bi:g/bo:g\@n/g;
		    }

		      if (($lemma =~ /[bB]ucht/) && ($PhonSylStBCLXwithoutbrackets =~ /bUxt/) )
		    {
			$PhonolSAM =~ s/bi:g/bUxt/g;
			$PhonolCLX =~ s/bi:g/bUxt/g;
		    }

		    

		     if (($lemma =~ /gnüg/) && ($PhonSylStBCLXwithoutbrackets =~ /gny:([kg])/) )
		    {
			#print "gnüg\n";
			$letterafter = $1;
			$PhonolSAM =~ s/g\@nu:g(\+\@)?/gny:${letterafter}/g;
			$PhonolCLX =~ s/g\@nu:g(\+\@)?/gny:${letterafter}/g;
		    }

		#    if (($lemma =~ /sücht/) && ($PhonSylStBCLXwithoutbrackets =~ /gny:([kg])/) )
		#    {
		#	#print "gnüg\n";
		##	$letterafter = $1;
		#	$PhonolSAM =~ s/g\@nu:g(\+\@)?/gny:${letterafter}/g;
		#	$PhonolCLX =~ s/g\@nu:g(\+\@)?/gny:${letterafter}/g;
		#    }

		    if ( ($PhonSylStBCLXwithoutbrackets =~ /o:st\@r/) && ($lemma =~ /[Oo]ster(.)/) )
		    {
			$letterafter = $1;
			if ($letterafter ne "n")
			{
			    $PhonolSAM =~ s/o:st\@rn/o:st\@r/g;
			    $PhonolCLX =~ s/o:st\@rn/o:st\@r/g;
			}
		    }
		    
		    if (($PhonSylStBCLXwithoutbrackets =~ /pfINst/)&& ($lemma =~ /Pfingst(..)/))
		    {
			$letterafter = $1;
			if ($letterafter ne "en")
			{
			    $PhonolSAM =~ s/pfINst\@n/pfINst/g;
			    $PhonolCLX =~ s/pfINst\@n/pfINst/g;
			}
		    }

		    
		    if (($lemma =~ /.ö./) && ($PhonSylStBCLXwithoutbrackets =~ /(.)([\&Q])(.)/))
		    {
			$letterbefore = $1;
			$vowel = $2;
			$oePhonolSAM = $hoePhonolSAM{$2};
			$letterafter = $3;
		#	print "ö $PhonSylStBCLXwithoutbrackets $PhonolSAM $letterbefore $letterafter\n";

			if (($letterafter =~ /[kpst]/) &&
			    (($PhonolSAM =~ /${letterbefore}[oO]([bdgz])\@?[\#\+]/) ||
			    ($PhonolSAM =~ /${letterbefore}[oO]([bdgz])\@?$/) )
			    && ($letterafter = $hvoicedvoiceless{$1}))
			{
			    $newletterafter = $1;
			    # print "newletterafter: $newletterafter\n";
			    $PhonolSAM =~ s/([${letterbefore}\#?])[oO]${newletterafter}\@?([\#\+])/$1${oePhonolSAM}${letterafter}$2/g;
			    $PhonolCLX =~ s/([${letterbefore}\#?])[oO]${newletterafter}\@?([\#\+])/$1${vowel}${letterafter}$2/g;
			    $PhonolSAM =~ s/([${letterbefore}\#?])[oO]${newletterafter}\@?$/$1${oePhonolSAM}${letterafter}/g;
			    $PhonolCLX =~ s/([${letterbefore}\#?])[oO]${newletterafter}\@?$/$1${vowel}${letterafter}/g;
			}

			elsif ($PhonolSAM =~ /${letterbefore}[oO]${letterafter}.*${letterbefore}[oO]${letterafter}/)
				# maybe problematic, take one phoneme more (wortwörtlich)
			{
			    $PhonSylStBCLXwithoutbrackets =~ /(.)${letterbefore}[\&Q]${letterafter}/;
			    $newletterbefore = "$1$letterbefore";
			    #print "double: $lemma $newletterbefore\n";
			    $PhonolSAM =~ s/(${newletterbefore}|\#${letterbefore})o${letterafter}/$1${oePhonolSAM}${letterafter}/;
			    $PhonolCLX =~ s/(${newletterbefore}|\#${letterbefore})o${letterafter}/$1${vowel}${letterafter}/;
			    
			    $PhonolSAM =~ s/(${newletterbefore}|\#${letterbefore})O${letterafter}/$1${oePhonolSAM}${letterafter}/;
			    $PhonolCLX =~ s/(${newletterbefore}|\#${letterbefore})O${letterafter}/$1${vowel}${letterafter}/;
			    $letterbefore = $1;
			}
			    
			elsif (($PhonSylStBCLXwithoutbrackets =~ /.[\&Q]..*(.)([\&Q])(.)/)
			    && ($PhonolSAM !~ /(${letterbefore}|\#)[oO]${letterafter}/) )  # 
			{
			    $letterbefore = $1;
			    $vowel = $2;
			    $letterafter = $3;
			 #   print "new: $letterbefore $vowel $letterafter\n";
			    $PhonolSAM =~ s/(${letterbefore}|\#)o${letterafter}/$1${oePhonolSAM}${letterafter}/;
			    $PhonolCLX =~ s/(${letterbefore}|\#)o${letterafter}/$1${vowel}${letterafter}/;
			    
			    $PhonolSAM =~ s/(${letterbefore}|\#)O${letterafter}/$1${oePhonolSAM}${letterafter}/;
			    $PhonolCLX =~ s/(${letterbefore}|\#)O${letterafter}/$1${vowel}${letterafter}/;
			}
			else
			{
			    $PhonolSAM =~ s/(${letterbefore}|\#)o${letterafter}/$1${oePhonolSAM}${letterafter}/;
			    $PhonolCLX =~ s/(${letterbefore}|\#)o${letterafter}/$1${vowel}${letterafter}/;
			    
			    $PhonolSAM =~ s/(${letterbefore}|\#)O${letterafter}/$1${oePhonolSAM}${letterafter}/;
			    $PhonolCLX =~ s/(${letterbefore}|\#)O${letterafter}/$1${vowel}${letterafter}/;
			    
			
			    # print "new PhonolSAM $PhonolSAM\n";
			}
		    }
		    
		    if ($lemma =~ /^[öÖ](.)/)
		    {
			# $letterbefore = $1;
			$letterafter = $1;
			$PhonolSAM =~ s/([\#]?)o${letterafter}/$1\|${letterafter}/g;
			$PhonolSAM =~ s/([\#]?)O${letterafter}/$1\/${letterafter}/g;
			$PhonolCLX =~ s/([\#]?)o${letterafter}/$1\&${letterafter}/g;
			$PhonolCLX =~ s/([\#]?)O${letterafter}/$1Q${letterafter}/g;
		    }		    

		    if (($lemma =~ /.äu./) && ($PhonSylStBCLXwithoutbrackets =~ /(.)Oy(.)/))
		    {
			$letterbefore = $1;
			$letterafter = $2;
		
			if (($letterafter =~ /[r]/) &&  ($PhonolSAM =~ /${letterbefore}au\@r/ ) )   # schwa: sauer -> säure
			{
			  #  print "l before/after: $letterbefore $letterafter in $PhonSylStBCLXwithoutbrackets\n";
			    
			    $PhonolSAM =~ s/([${letterbefore}\#?])au\@${letterafter}/$1Oy${letterafter}/g;
			    $PhonolCLX =~ s/([${letterbefore}\#?])au\@${letterafter}/$1Oy${letterafter}/g;	
			}

			elsif (($letterafter =~ /[kpst]/) &&
			       ($PhonolSAM =~ /${letterbefore}au([bdgz])\@?[\#\+]?/) &&
			       ($letterafter = $hvoicedvoiceless{$1}))
			{
			    $newletterafter = $1;
			    # print "$lemma newletterafter: $newletterafter\n";
			    $PhonolSAM =~ s/([${letterbefore}\#?])au${newletterafter}\@?([\#\+]?)/$1Oy${letterafter}$2/g;
			    $PhonolCLX =~ s/([${letterbefore}\#?])au${newletterafter}\@?([\#\+]?)/$1Oy${letterafter}$2/g;
			}
			else
			{
			    $PhonolSAM =~ s/([${letterbefore}\#])au${letterafter}/$1Oy${letterafter}/g;
			    $PhonolCLX =~ s/([${letterbefore}\#])au${letterafter}/$1Oy${letterafter}/g;
			}
		    }
		    ###
		    if (($lemma =~ /.äu/) && ($PhonSylStBCLXwithoutbrackets =~ /(.)Oy$/)) # bläuen, Gebräu
		    {
			$letterbefore = $1;
			$PhonolSAM =~ s/([${letterbefore}\#])au$/$1Oy/g;
			$PhonolCLX =~ s/([${letterbefore}\#])au$/$1Oy/g;
		    }

		    ###
		    
		    if (($lemma =~ /^[äÄ]u/) && ($PhonSylStBCLXwithoutbrackets =~ /^Oy(.)/))
		    {
			$letterafter = $1;
		#	print "Äu: $letterafter\n";
			
			if (($letterafter =~ /[kpst]/) && ($PhonolSAM =~ /^au([bdgz])\@?[\#\+]/)
			    && ($letterafter = $hvoicedvoiceless{$1}))
			{
			   $newletterafter = $1;
		#	   print "newletterafter: $newletterafter\n";
			   $PhonolSAM =~ s/([\#]?)au${newletterafter}\@?([\#\+])/$1Oy${letterafter}$2/g;
			   $PhonolCLX =~ s/([\#]?)au${newletterafter}\@?([\#\+])/$1Oy${letterafter}$2/g;	    
			}
			else
			{
			    $PhonolSAM =~ s/([\#]?)au${letterafter}/$1Oy${letterafter}/g;
			    $PhonolCLX =~ s/([\#]?)au${letterafter}/$1Oy${letterafter}/g;
			}
		    }
		    
		    if (($lemma =~ /.ä./) && ($PhonSylStBCLXwithoutbrackets =~ /(.)(E:?)(.)/))
		    {
			$letterbefore = $1;
			$vowel = $2;
			$letterafter = $3;
			
		#	print "PhonSylStBCLXwithoutbrackets/stransformed $PhonSylStBCLXwithoutbrackets / $stransformed Lemma: $lemma,
											#      $letterbefore Vowel: $vowel $letterafter\n";

			
			if (($letterafter =~ /[kpst]/) &&
			    (($PhonolSAM =~ /${letterbefore}a:?([bdgz])\@?[\#\+]/) ||
			     ($PhonolSAM =~ /${letterbefore}a:?([bdgz])\@?$/) )
			    && ($letterafter = $hvoicedvoiceless{$1}))
			{
			    $newletterafter = $1;
		#	    print "newletterafter: $newletterafter\n";
			    $PhonolSAM =~ s/([${letterbefore}\#?])a:?${newletterafter}\@?([\#\+])/$1${vowel}${letterafter}$2/g;
			    $PhonolCLX =~ s/([${letterbefore}\#?])a:?${newletterafter}\@?([\#\+])/$1${vowel}${letterafter}$2/g;
			    $PhonolSAM =~ s/([${letterbefore}\#?])a:?${newletterafter}\@?$/$1${vowel}${letterafter}/g;
			    $PhonolCLX =~ s/([${letterbefore}\#?])a:?${newletterafter}\@?$/$1${vowel}${letterafter}/g;	    			   
		#	    print "PhonolSAM: $PhonolSAM\n";
			}
		#	else
		#	{
		#	print "$letterbefore Vowel: $vowel $letterafter $PhonolSAM\n";
			
			if ($PhonolSAM =~ /${letterbefore}a:?${letterafter}.*${letterbefore}a:?${letterafter}/)
			    # maybe problematic, take one phoneme more (Glasbläser)
			{
			    $PhonSylStBCLXwithoutbrackets =~ /(.)${letterbefore}(E:?)${letterafter}/;
			    $newletterbefore = "$1$letterbefore";
			 #   print "double: $lemma $newletterbefore\n";
			    $PhonolSAM =~ s/(${newletterbefore}|\#${letterbefore})a:?${letterafter}/$1${vowel}${letterafter}/;
			    $PhonolCLX =~ s/(${newletterbefore}|\#${letterbefore})a:?${letterafter}/$1${vowel}${letterafter}/;
			    $letterbefore = $1;
			}
			
			# verzärteln
			
			if (($PhonSylStBCLXwithoutbrackets =~ /.E:?..*(.)(E:?)(.)/)
			    && ($PhonolSAM !~ /(${letterbefore}|\#)a:?${letterafter}/) )  # "far" does not exist, try next with zar
			{
			    $letterbefore = $1;
			    $vowel = $2;
			    $letterafter = $3;
			    #print "new: $letterbefore $vowel $letterafter\n";
			}
			
			$PhonolSAM =~ s/(${letterbefore}|\#)a:?${letterafter}/$1${vowel}${letterafter}/;
			$PhonolCLX =~ s/(${letterbefore}|\#)a:?${letterafter}/$1${vowel}${letterafter}/;
			#print "PhonolSam: $PhonolSAM\n";
		#	}
		    }

		    if (($lemma =~ /^[äÄ]/) && ($PhonSylStBCLXwithoutbrackets =~ /^(E:?)(.)/))
		    {
			$vowel = $1;
			$letterafter = $2;
		#	print "Ä: $letterafter\n";
			$PhonolSAM =~ s/([\#]?)a:?${letterafter}/$1${vowel}${letterafter}/g;
			$PhonolCLX =~ s/([\#]?)a:?${letterafter}/$1${vowel}${letterafter}/g;
		    }
		    
		    if (($lemma =~ /.ü./) && ($PhonSylStBCLXwithoutbrackets =~ /(.)([yY]:?)(.)/))
		    {   # also mistake at Erschütterung etc.
			$letterbefore = $1;
			$vowel = $2;
			$letterafter = $3;
		#	print "l before/after: $letterbefore $letterafter\n";

			if (($letterafter =~ /[kpst]/) &&
			    (($PhonolSAM =~ /${letterbefore}[uU]:?([bdgz])\@?[\#\+]/) ||
			     ($PhonolSAM =~ /${letterbefore}[uU]:?([bdgz])\@?$/) ) 
			    && ($letterafter = $hvoicedvoiceless{$1}))
			{
			    $newletterafter = $1;
		#	    print "newletterafter: $newletterafter\n";
			    $PhonolSAM =~ s/([${letterbefore}\#?])[uU]:?${newletterafter}\@?([\#\+])/$1${vowel}${letterafter}$2/g;
			    $PhonolCLX =~ s/([${letterbefore}\#?])[uU]:?${newletterafter}\@?([\#\+])/$1${vowel}${letterafter}$2/g;
			    $PhonolSAM =~ s/([${letterbefore}\#?])[uU]:?${newletterafter}\@?$/$1${vowel}${letterafter}/g;
			    $PhonolCLX =~ s/([${letterbefore}\#?])[uU]:?${newletterafter}\@?$/$1${vowel}${letterafter}/g;	    			   
			}

			if ($PhonolSAMwithoutdel =~ /${letterbefore}i:${letterafter}/) # überflüssig etc. 
			{
			    $PhonolSAM =~ s/([${letterbefore}\#])i:${letterafter}/$1${vowel}${letterafter}/g;
			    $PhonolCLX =~ s/([${letterbefore}\#])i:${letterafter}/$1${vowel}${letterafter}/g;  
			}

			if ($PhonolSAM =~ /${letterbefore}[uU]:?${letterafter}.*${letterbefore}[uU]:?${letterafter}/)
				# maybe problematic, take one phoneme more 
			{
			    $PhonSylStBCLXwithoutbrackets =~ /(.)${letterbefore}[\&Q]${letterafter}/;
			    $newletterbefore = "$1$letterbefore";
			   #  print "double: $lemma $newletterbefore\n";
			    $PhonolSAM =~ s/(${newletterbefore}|\#${letterbefore})[uU]:?${letterafter}/$1${vowel}${letterafter}/;
			    $PhonolCLX =~ s/(${newletterbefore}|\#${letterbefore})[uU]:?${letterafter}/$1${vowel}${letterafter}/;
			    $letterbefore = $1;
			}

			if (($PhonSylStBCLXwithoutbrackets =~ /.[yY]:?..*(.)([yY]:?)(.)/)
			    && ($PhonolSAM !~ /(${letterbefore}|\#)[uU]:?${letterafter}/) )  # 
			{
			    $letterbefore = $1;
			    $vowel = $2;
			    $letterafter = $3;
			#    print "new: $letterbefore $vowel $letterafter\n";  # Zündschlüssel will not be changed for i:
			    $PhonolSAM =~ s/(${letterbefore}|\#)[uU]:?${letterafter}/$1${vowel}${letterafter}/;
			    $PhonolCLX =~ s/(${letterbefore}|\#)[uU]:?${letterafter}/$1${vowel}${letterafter}/;
			}
			

			if ($PhonolSAM =~ /${letterbefore}[uU]:?${letterafter}.*${letterbefore}[yY]:?${letterafter}/)
				# maybe problematic, ??? take one phoneme more 
			{
			    $PhonSylStBCLXwithoutbrackets =~ /(.)${letterbefore}[yY]:?${letterafter}/;
			    $newletterbefore = "$1$letterbefore";
			    #print "double: $lemma $newletterbefore\n";
			    $PhonolSAM =~ s/(${newletterbefore}|\#${letterbefore})[yY]:?${letterafter}/$1${vowel}${letterafter}/;
			    $PhonolCLX =~ s/(${newletterbefore}|\#${letterbefore})[yY]:?${letterafter}/$1${vowel}${letterafter}/;
			    
			   # $PhonolSAM =~ s/(${newletterbefore}|\#${letterbefore})O${letterafter}/$1${vowel}${letterafter}/;
			    #$PhonolCLX =~ s/(${newletterbefore}|\#${letterbefore})O${letterafter}/$1${vowel}${letterafter}/;
			    
			}
			
		 	if (($PhonSylStBCLXwithoutbrackets =~ /.[yY]:?..*(.)([yY]:?)(.)/) #  also finds Zündschlüssel
		 	    && ($PhonolSAM !~ /(${letterbefore}|\#)[uU]:?${letterafter}/) )  # Grüngürtel: run does not exist, try gur
		 	{
		 	    $letterbefore = $1;
		 	    $vowel = $2;
		 	    $letterafter = $3;
		 	#    print "new: $letterbefore $vowel $letterafter\n";
		 	    $PhonolSAM =~ s/([${letterbefore}\#])i:${letterafter}/$1${vowel}${letterafter}/g;
		 	    $PhonolCLX =~ s/([${letterbefore}\#])i:${letterafter}/$1${vowel}${letterafter}/g;  
		 	}
			
			$PhonolSAM =~ s/([${letterbefore}\#])[uU]:?${letterafter}/$1${vowel}${letterafter}/g;
			$PhonolCLX =~ s/([${letterbefore}\#])[uU]:?${letterafter}/$1${vowel}${letterafter}/g;
		    }

		    
		    if (($lemma =~ /^[üÜ]./) && ($PhonSylStBCLXwithoutbrackets =~ /^([yY]:?)(.)/) )
		    {
			$letterbefore = $1;
			$letterafter = $2;
			$PhonolSAM =~ s/([\#]?)u:?${letterafter}/$1${letterbefore}${letterafter}/g;
			$PhonolCLX =~ s/([\#]?)u:?${letterafter}/$1${letterbefore}${letterafter}/g;
		    }
		    

		    
		     if (($lemma =~ /[Ff]uhr/) && ($PhonSylStBCLXwithoutbrackets =~ /fu:r/) )
		    {
			$PhonolSAM =~ s/fy:r/fu:r/g;
			$PhonolSAM =~ s/fa:r/fu:r/g;
			$PhonolCLX =~ s/fy:r/fu:r/g;
			$PhonolCLX =~ s/fa:r/fu:r/g;
		    }


		     if (($lemma =~ /[Ae]ro/) && ($PhonSylStBCLXwithoutbrackets =~ /ae:ro:/) )
		    {
			$PhonolSAM =~ s/aero:/ae:ro:/g;
			$PhonolCLX =~ s/aero:/ae:ro:/g;
		    }
		    
		    if (($lemma =~ /[Bb]ot/) && ($PhonSylStBCLXwithoutbrackets =~ /bo:t/) )
		    {
			$PhonolSAM =~ s/bi:t/bo:t/g;
			$PhonolCLX =~ s/bi:t/bo:t/g;
		    }

		     if (($lemma =~ /[bB]rut/) && ($PhonSylStBCLXwithoutbrackets =~ /bru:t/) )
		    {
			$PhonolSAM =~ s/bry:t/bru:t/g;
			$PhonolCLX =~ s/bry:t/bru:t/g;
		    }

		    if (($lemma =~ /[Ää]hnl/) && ($PhonSylStBCLXwithoutbrackets =~ /E:nl/) )
		    {
			$PhonolSAM =~ s/E:n\@l/E:nl/g;
			$PhonolCLX =~ s/E:n\@l/E:nl/g;
		    }
		    
		    
		    if (($lemma =~ /[bBp]r[uü]ch/) && ($PhonSylStBCLXwithoutbrackets =~ /([pb])r([UY])x/) ) # Bruch, Spruch
		    {
			$letterbefore = $1;
			$vowel = $2;
			$PhonolSAM =~ s/${letterbefore}rEx/${letterbefore}r${vowel}x/g;
			$PhonolCLX =~ s/${letterbefore}rEx/${letterbefore}r${vowel}x/g;
		    }

		     if (($lemma =~ /[bB]und/) && ($PhonSylStBCLXwithoutbrackets =~ /bUn([dt])/) )
		    {
			$letterafter = $1;	      
			$PhonolSAM =~ s/bInd/bUn${letterafter}/g;
			$PhonolCLX =~ s/bInd/bUn${letterafter}/g;
		    }
		    if (($lemma =~ /[bB]ünd/) && ($PhonSylStBCLXwithoutbrackets =~ /bYnd/) )
		    {
			$PhonolSAM =~ s/bInd/bYnd/g;
			$PhonolCLX =~ s/bInd/bYnd/g;
		    }

		    

		     if (($lemma =~ /d[aä]cht/) && ($PhonSylStBCLXwithoutbrackets =~ /d([aE])xt/) )
		    {
			$vowel = $1;
			$PhonolSAM =~ s/dENk/d${vowel}xt/g;
			$PhonolCLX =~ s/dENk/d${vowel}xt/g;
		    }
		    
		    if (($lemma =~ /damal/) && ($PhonSylStBCLXwithoutbrackets =~ /da:ma:l/) )
		    {
			#$vowel = $1;
			$PhonolSAM =~ s/da:#ma:l\+s\+/da:#ma:l\+/g;
			$PhonolCLX =~ s/da:#ma:l\+s\+/da:#ma:l\+/g;
		    }
		    if (($lemma =~ /darf/) && ($PhonSylStBCLXwithoutbrackets =~ /darf/) )
		    {
			$PhonolSAM =~ s/dYrf/darf/g;
			$PhonolCLX =~ s/dYrf/darf/g;
		    }
		    

		    if (($lemma =~ /[Dd]örr/) && ($PhonSylStBCLXwithoutbrackets =~ /dQr/) )
		    {
			$PhonolSAM =~ s/dYr/d\/r/g;
			$PhonolCLX =~ s/dYr/dQr/g;
		    }


		    if (($lemma =~ /[Dd]rit/) && ($PhonSylStBCLXwithoutbrackets =~ /drIt/) )
		    {
			$PhonolSAM =~ s/drai\+t/drIt/g;
			$PhonolCLX =~ s/drai\+t/drIt/g;
		    }
		    
		   # if (($lemma =~ /[Dd]rin/) && ($PhonSylStBCLXwithoutbrackets =~ /drIn/) )
		   # {
		#	$PhonolSAM =~ s/da:\+r#In/drIn/g;
		#	$PhonolCLX =~ s/da:\+r#In/drIn/g;
		   # }
		    
		    if (($lemma =~ /[Dd]roll/) && ($PhonSylStBCLXwithoutbrackets =~ /drOl/) )
		    {
			$PhonolSAM =~ s/dral/drOl/g;
			$PhonolCLX =~ s/dral/drOl/g;
		    }

		    
		     if (($lemma =~ /[Dd]ruck/) && ($PhonSylStBCLXwithoutbrackets =~ /drUk/) )
		    {
			$PhonolSAM =~ s/drYk/drUk/g;
			$PhonolCLX =~ s/drYk/drUk/g;
		    }

		    if (($lemma =~ /[jJ]agd/) && ($PhonSylStBCLXwithoutbrackets =~ /ja:kt/) )
		    {
			$PhonolSAM =~ s/ja:g/ja:kt/g;
			$PhonolCLX =~ s/ja:g/ja:kt/g;
		    }
		    
		     if (($lemma =~ /[kK]ampf/) && ($PhonSylStBCLXwithoutbrackets =~ /kampf/) )
		    {
			$PhonolSAM =~ s/kEmpf/kampf/g;
			$PhonolCLX =~ s/kEmpf/kampf/g;
		    }

		    if (($lemma =~ /[kK]lammer/) && ($PhonSylStBCLXwithoutbrackets =~ /klam\@r/) )
		    {
			$PhonolSAM =~ s/klEm/klam/g;
			$PhonolCLX =~ s/klEm/klam/g;
		    }
		    
		    if (($lemma =~ /klomm/) && ($PhonSylStBCLXwithoutbrackets =~ /klOm/) ) # beklommen
		    {
			$PhonolSAM =~ s/klam/klOm/g;
			$PhonolCLX =~ s/klam/klOm/g;
		    }
		    
		    
		    if (($lemma =~ /[kK]niff/) && ($PhonSylStBCLXwithoutbrackets =~ /knIf/) )
		    {
			$PhonolSAM =~ s/knaif/knIf/g;
			$PhonolCLX =~ s/knaif/knIf/g;
		    }
		    

		    # must come before lag
		    if (($lemma =~ /flicht/) && ($PhonSylStBCLXwithoutbrackets =~ /pflIxt/) )
		    {
			$PhonolSAM =~ s/pfle:g/pflIxt/g;
			$PhonolCLX =~ s/pfle:g/pflIxt/g;
		    }

		   
		    if (($lemma =~ /lag/) && ($PhonSylStBCLXwithoutbrackets =~ /la:([gk]\@?)/) )
		    {
			$letterafter = $1;
			$PhonolSAM =~ s/le:g/la:${letterafter}/g;
			$PhonolCLX =~ s/le:g/la:${letterafter}/g;
		    }

		    
 		    if (($lemma =~ /[Ss]chlacht/) && ($PhonSylStBCLXwithoutbrackets =~ /Slax/) )
		    {
			$PhonolSAM =~ s/Sla:g\+t/Slaxt/g;
			$PhonolCLX =~ s/Sla:g\+t/Slaxt/g;
		    }

		    if (($lemma =~ /[Ss]chlack/) && ($PhonSylStBCLXwithoutbrackets =~ /Slak/) )
		    {
			$PhonolSAM =~ s/Sla:g/Slak/g;
			$PhonolCLX =~ s/Sla:g/Slak/g;
		    }

		    if (($lemma =~ /chlack/) && ($PhonSylStBCLXwithoutbrackets =~ /Slak/) )
		    {
			$PhonolSAM =~ s/Sla:g/Slak/g;
			$PhonolCLX =~ s/Sla:g/Slak/g;
		    }

		     if (($lemma =~ /chmuck/) && ($PhonSylStBCLXwithoutbrackets =~ /SmUk/) )
		    {
			$PhonolSAM =~ s/SmYk/SmUk/g;
			$PhonolCLX =~ s/SmYk/SmUk/g;
		    }
		    
		    if (($lemma =~ /chorf/) && ($PhonSylStBCLXwithoutbrackets =~ /SOrf/) )
		    {
			$PhonolSAM =~ s/Sarf/SOrf/g;
			$PhonolCLX =~ s/Sarf/SOrf/g;
		    }
		    
		     if (($lemma =~ /chwist/) && ($PhonSylStBCLXwithoutbrackets =~ /SvIs/) )
		    {
			$PhonolSAM =~ s/SvEs/SvIs/g;
			$PhonolCLX =~ s/SvEs/SvIs/g;
		    }

		     if (($lemma =~ /chutz/) && ($PhonSylStBCLXwithoutbrackets =~ /SUts/) )
		    {
			$PhonolSAM =~ s/SYts/SUts/g;
			$PhonolCLX =~ s/SYts/SUts/g;
		    } 

		   # $letterafter = "";
		      if (($lemma =~ /[Ss]pr[aä]ch/) && ($PhonSylStBCLXwithoutbrackets =~ /Spr([Ea]):x(.?)/) )
		    {
			$vowel = $1;
			$letterafter = $2;
			if ($letterafter eq "\@")
			{
			    $PhonolSAM =~ s/SprEx/Spra:x\@/g;
			    $PhonolCLX =~ s/SprEx/Spra:x\@/g;
			}
			else
			{
			    $PhonolSAM =~ s/SprEx/Spr${vowel}:x/g;
			    $PhonolCLX =~ s/SprEx/Spr${vowel}:x/g;  
			}
		    }

		    if (($lemma =~ /[eE]del/) && ($PhonSylStBCLXwithoutbrackets =~ /e:d\@l/) )
		    {
			$PhonolSAM =~ s/a:d\@l/e:d\@l/;
			$PhonolCLX =~ s/a:d\@l/e:d\@l/;
		    }

		    if (($lemma =~ /roti/) && ($PhonSylStBCLXwithoutbrackets =~ /e:ro:tI/) )# eroti
		    {
		#	print "roti: $PhonolSAM\n";
			$PhonolSAM =~ s/e:rOs\+/e:ro:t/;
			$PhonolCLX =~ s/e:rOs\+/e:ro:t/;
		    }
  
		    
		    if (($lemma =~ /[Ff]ähig/) && ($PhonSylStBCLXwithoutbrackets =~ /fE:Ix/) )
		    {
			$PhonolSAM =~ s/fE:Ig/fE:Ix/;
			$PhonolCLX =~ s/fE:Ig/fE:Ix/;
		    }

		    if (($lemma =~ /[Ff]und/) && ($PhonSylStBCLXwithoutbrackets =~ /fUnt/) )
		    {
			$PhonolSAM =~ s/fInd/fUnt/;
			$PhonolCLX =~ s/fInd/fUnt/;
		    }
		    
		    if (($lemma =~ /[fF]l[uü]cht/) && ($PhonSylStBCLXwithoutbrackets =~ /fl([UY])xt/) )
		    {
			$vowel = $1;
			$PhonolSAM =~ s/fli:/fl${vowel}xt/;
			$PhonolCLX =~ s/fli:/fl${vowel}xt/;
		    }
		    
		    if (($lemma =~ /[Ff]lug/) && ($PhonSylStBCLXwithoutbrackets =~ /flu:k/) )
		    {
			$PhonolSAM =~ s/fli:g/flu:g/;
			$PhonolCLX =~ s/fli:g/flu:g/;
		    }


		    if (($lemma =~ /[Ff]luss/) && ($PhonSylStBCLXwithoutbrackets =~ /flUs/) )
		    {
			$PhonolSAM =~ s/fli:s/flUs/g;
			$PhonolCLX =~ s/fli:s/flUs/g;
		    }
		    
		    if (($lemma =~ /[fF]rost/) && ($PhonSylStBCLXwithoutbrackets =~ /frOst/) )
		    {
			$PhonolSAM =~ s/fri:r/frOst/g;
			$PhonolCLX =~ s/fri:r/frOst/g;
		    }
		    
		    if (($lemma =~ /[fF]ug/) && ($PhonSylStBCLXwithoutbrackets =~ /fu:([gk])/) )
		    {
			$vowel = $1;
			$PhonolSAM =~ s/fy:g/fu:${vowel}/g;
			$PhonolCLX =~ s/fy:g/fu:${vowel}/g;
		    }
		    

		    if (($lemma =~ /[Gg]ab/) && ($PhonSylStBCLXwithoutbrackets =~ /ga:b\@/))
		    {
			$PhonolSAM =~ s/ge:b/ga:b\@/g;
			$PhonolCLX =~ s/ge:b/ga:b\@/g;
		    }
		    
		    if (($lemma =~ /birg/) && ($PhonSylStBCLXwithoutbrackets =~ /bIrg/))
		    {
			$PhonolSAM =~ s/bErg/bIrg/g;
			$PhonolCLX =~ s/bErg/bIrg/g;
		    }
		    
		    if (($lemma =~ /[Gg]enick/) && ($PhonSylStBCLXwithoutbrackets =~ /g\@ni:k/))
		    {
			$PhonolSAM =~ s/g\@#nak\@n/g\@ni:k/g;
			$PhonolCLX =~ s/g\@#nak\@n/g\@ni:k/g;
		    }

		    $letterafter = "";
		    if (($lemma =~ /[Gg]eschicht/) && ($PhonSylStBCLXwithoutbrackets =~ /g\@SIxt(.)/))
		    {
			$letterafter = $1;
			if ($letterafter eq "\@")
			{
			    $PhonolSAM =~ s/g\@Se:#t\@/g\@SIxt\@/g;
			    $PhonolCLX =~ s/g\@Se:#t\@/g\@SIxt\@/g;  
			}
		    
			else
			{
			    $PhonolSAM =~ s/g\@Se:#t\@/g\@SIxt/g;
			    $PhonolCLX =~ s/g\@Se:#t\@/g\@SIxt/g;
			}
		    }

		    

		    if (($lemma =~ /[gG]lanz/) && ($PhonSylStBCLXwithoutbrackets =~ /glants/))
		    {
			$PhonolSAM =~ s/glEnts/glants/g;
			$PhonolCLX =~ s/glEnts/glants/g;
		    }
		    
		    if (($lemma =~ /[Gg]äng/) && ($PhonSylStBCLXwithoutbrackets =~ /gEN/))
		    {
			$PhonolSAM =~ s/ge\:/gEN/g;
			$PhonolCLX =~ s/ge\:/gEN/g;
		    }

		    if (($lemma =~ /[gG]ang/) && ($PhonSylStBCLXwithoutbrackets =~ /gaN/))
		    {
			$PhonolSAM =~ s/ge\:/gaN/g;
			$PhonolCLX =~ s/ge\:/gaN/g;
		    }


		    if (($lemma =~ /[gG]ewohn/) && ($PhonSylStBCLXwithoutbrackets =~ /g\@vo:n/))
		    {
			$PhonolSAM =~ s/g\@v\|:n/g\@vo:n/g;
			$PhonolCLX =~ s/g\@v\&:n/g\@vo:n/g;
		    }

		    
		    if (($lemma =~ /[gG]ift/) && ($PhonSylStBCLXwithoutbrackets =~ /gIft/))
		    {
			$PhonolSAM =~ s/ge\:b/gIft/g;
			$PhonolCLX =~ s/ge\:b/gIft/g;
		    }

		    if (($lemma =~ /[gG]riff/) && ($PhonSylStBCLXwithoutbrackets =~ /grIf/))
		    {
			$PhonolSAM =~ s/graif/grIf/g;
			$PhonolCLX =~ s/graif/grIf/g;
		    }


		    if (($lemma =~ /[pP]fiff/) && ($PhonSylStBCLXwithoutbrackets =~ /pfIf/))
		    {
			$PhonolSAM =~ s/pfaif/pfIf/g;
			$PhonolCLX =~ s/pfaif/pfIf/g;
			$PhonolSAM =~ s/pfEf\@r/pfIf\@r/g;
			$PhonolCLX =~ s/pfEf\@r/pfIf\@r/g;
		    }
		    
		    
		    if (($lemma =~ /[gG]rub/) && ($PhonSylStBCLXwithoutbrackets =~ /gru:b/))
		    {
			$PhonolSAM =~ s/gra:b/gru:b\@/g;
			$PhonolCLX =~ s/gra:b/gru:b\@/g;
		    }

		    if (($lemma =~ /[gG]ült/) && ($PhonSylStBCLXwithoutbrackets =~ /gYlt/))
		    {
			$PhonolSAM =~ s/gElt/gYlt\@/g;
			$PhonolCLX =~ s/gElt/gYlt\@/g;
		    }

		     if (($lemma =~ /[gG][uü]nst/) && ($PhonSylStBCLXwithoutbrackets =~ /g([YU])nst/))
		    {
			$vowel = $1;
			$PhonolSAM =~ s/g\/n/g${vowel}nst/g;
			$PhonolCLX =~ s/gQn/g${vowel}nst/g;
		    }
		    
		    
		    if (($lemma =~ /[Ii]ntern/) && ($PhonSylStBCLXwithoutbrackets =~ /Int\@r/)) # internalisieren
		    {
			$PhonolSAM =~ s/IntEr/Int\@r/g;
			$PhonolCLX =~ s/IntEr/Int\@r/g;
		    }

		    if (($lemma =~ /sycho/) && ($PhonSylStBCLXwithoutbrackets =~ /psy:xo:/)) # internalisieren
		    {
			$PhonolSAM =~ s/psy:x\@/psy:xo:/g;
			$PhonolCLX =~ s/psy:x\@/psy:xo:/g;
		    }
		    
		    if (($lemma =~ /[sS]atz/) && ($PhonSylStBCLXwithoutbrackets =~ /zats/))
		    {
			$PhonolSAM =~ s/zEts/zats/g;
			$PhonolCLX =~ s/zEts/zats/g;
		    }

		    if (($lemma =~ /[r]ieb/) && ($PhonSylStBCLXwithoutbrackets =~ /ri:p/))
		    {
			$PhonolSAM =~ s/raib/ri:p/g;
			$PhonolCLX =~ s/raib/ri:p/g;
		    }

		    if (($lemma =~ /[sS]chied/) && ($PhonSylStBCLXwithoutbrackets =~ /Si:t/))
		    {
			$PhonolSAM =~ s/Said/Si:t/g;
			$PhonolCLX =~ s/Said/Si:t/g;
		    }

		     if (($lemma =~ /chrift/) && ($PhonSylStBCLXwithoutbrackets =~ /SrIft/))
		    {
			$PhonolSAM =~ s/Sraib/SrIft/g;
			$PhonolCLX =~ s/Sraib/SrIft/g;
		    }

		     if (($lemma =~ /chwitz/) && ($PhonSylStBCLXwithoutbrackets =~ /SvIts/))
		    {
			$PhonolSAM =~ s/Svais/SvIts/g;
			$PhonolCLX =~ s/Svais/SvIts/g;
		    }
		    
		    if (($lemma =~ /selig/) && ($PhonSylStBCLXwithoutbrackets =~ /ze:lIx/))
		    {
			$PhonolSAM =~ s/za:l\+Ix/ze:l\+Ix/g;
			$PhonolCLX =~ s/za:l\+Ix/ze:l\+Ix/g;
		    }
		    
		    
		    if (($lemma =~ /[sS]icht/) && ($PhonSylStBCLXwithoutbrackets =~ /zIxt/))
		    {
			$PhonolSAM =~ s/ze:/zIxt/g;
			$PhonolCLX =~ s/ze:/zIxt/g;
		    }
		    
		    if (($lemma =~ /[sS]tieg/) && ($PhonSylStBCLXwithoutbrackets =~ /Sti:([gk])/))
		    {
			$letterafter = $1;
			$PhonolSAM =~ s/Staig/Sti:${letterafter}/g;
			$PhonolCLX =~ s/Staig/Sti:${letterafter}/g;
		    }

		    if (($lemma =~ /[sS]tich/) && ($PhonSylStBCLXwithoutbrackets =~ /StIx/))
		    {
			$PhonolSAM =~ s/StEx/StIx/g;
			$PhonolCLX =~ s/StEx/StIx/g;
		    }
		    
		    if (($lemma =~ /[sS]törr/) && ($PhonSylStBCLXwithoutbrackets =~ /St&:r/))
		    {
			$PhonolSAM =~ s/Star/St\|r/g;
			$PhonolCLX =~ s/Star/St&:r/g;
		    }
		    

		    if (($lemma =~ /[sS]trich/) && ($PhonSylStBCLXwithoutbrackets =~ /StrIx/))
		    {
			$PhonolSAM =~ s/Straix/StrIx/g;
			$PhonolCLX =~ s/Straix/StrIx/g;
		    }

		    
		     if (($lemma =~ /[sS]trub/) && ($PhonSylStBCLXwithoutbrackets =~ /StrUb(\@?)l/))
		    {
			$vowel = $1;
			$PhonolSAM =~ s/Stro:b\@l/StrUb${vowel}l/g;
			$PhonolCLX =~ s/Stro:b\@l/StrUb${vowel}l/g;
		    }

		    if ($lemma =~ /churz/) ## && ($PhonSylStBCLXwithoutbrackets =~ /SUrts/)) # mistake at Schurz
		    {
			$PhonolSAM =~ s/Sy:rts/SUrts/g;
			$PhonolCLX =~ s/Sy:rts/SUrts/g;
		    }

		    
		    
		    if (($lemma =~ /[sS]tur[zm]/) && ($PhonSylStBCLXwithoutbrackets =~ /StUr(ts|m)/))
		    {
			$PhonolSAM =~ s/StYr/StUr/g;  # Sturz, Ansturm
			$PhonolCLX =~ s/StYr/StUr/g;
		    }

		    if (($lemma =~ /[sS]ucht/) && ($PhonSylStBCLXwithoutbrackets =~ /zUxt/))
		    {
			$PhonolSAM =~ s/zu:x\+\@\+t/zUxt/g;
			$PhonolCLX =~ s/zu:x\+\@\+t/zUxt/g;
		    }

		    if (($lemma =~ /Trub/) && ($PhonSylStBCLXwithoutbrackets =~ /tru:p/))
		    {
			$PhonolSAM =~ s/try:b\@/tru:p/g;
			$PhonolCLX =~ s/try:b\@/tru:p/g;
		    }
##
		    if (($lemma =~ /[Tt](r?)unk/) && ($PhonSylStBCLXwithoutbrackets =~ /t(r?)UNk/))
		    {
			$letterbefore = $1;
			$PhonolSAM =~ s/t${letterbefore}INk/t${letterbefore}UNk/g;
			$PhonolCLX =~ s/t${letterbefore}INk/t${letterbefore}UNk/g;
		    }

		    if (($lemma =~ /[Tt](r?)ank/) && ($PhonSylStBCLXwithoutbrackets =~ /t(r?)aNk/))
		    {
			$letterbefore = $1;
			$PhonolSAM =~ s/t${letterbefore}INk/t${letterbefore}aNk/g;
			$PhonolCLX =~ s/t${letterbefore}INk/t${letterbefore}aNk/g;
		    }


		    if (($lemma =~ /[Tt]ränk/) && ($PhonSylStBCLXwithoutbrackets =~ /trENk/))
		    {
			$PhonolSAM =~ s/trINk/trENk/g;
			$PhonolCLX =~ s/trINk/trENk/g;
		    }

		    if (($lemma =~ /[Tt]rünk/) && ($PhonSylStBCLXwithoutbrackets =~ /trYNk/))
		    {
			$PhonolSAM =~ s/trINk/trYNk/g;
			$PhonolCLX =~ s/trINk/trYNk/g;
		    }
		    
	##	    
		    
		    if (($lemma =~ /okab/) && ($PhonSylStBCLXwithoutbrackets =~ /o:ka:?b/))
		    {
			$PhonolSAM =~ s/o:ka:l#b/o:ka:#b/g;
			$PhonolCLX =~ s/o:ka:l#b/o:ka:#b/g;
		    }

		    if (($lemma =~ /[Zz]oo/) && ($PhonSylStBCLXwithoutbrackets =~ /tso:o:/))
		    {
			$PhonolSAM =~ s/tso:/tso:o:/g;
			$PhonolCLX =~ s/tso:/tso:o:/g;
		    }

		    

		     if (($lemma =~ /[rR]ück/) && ($PhonSylStBCLXwithoutbrackets =~ /(?<!tsu:)rYk(?!\@n)/) )
		    {
			$PhonolSAM =~ s/^tsu:rYk/rYk/g;
			$PhonolCLX =~ s/^tsu:rYk/rYk/g;
			$PhonolSAM =~ s/rYk\@n/rYk/g;
			$PhonolCLX =~ s/rYk\@n/rYk/g;
			$PhonolSAM =~ s/#tsu:rYk/#rYk/g;
			$PhonolCLX =~ s/#tsu:rYk/#rYk/g;
		    }


		    if ($PhonSylStBCLXwithoutbrackets =~ /[brS]Is/)
		    {
			$PhonolSAM =~ s/([brS])ais/$1Is/g;
			$PhonolCLX =~ s/([brS])ais/$1Is/g;
		    }

		    if (($lemma =~ /ar/) && ($PhonSylStBCLXwithoutbrackets =~ /(.)(a:?)r/))
		    {
			$letterbefore = $1;
			$vowel = $2;
			#print "Lemma: $lemma\n";
			$PhonolSAM =~ s/${letterbefore}E:r/${letterbefore}${vowel}r/g; # Militarismus, demilitarisieren
			$PhonolCLX =~ s/${letterbefore}E:r/${letterbefore}${vowel}r/g;
		    }

		    if (($lemma =~ /ular/) && ($PhonSylStBCLXwithoutbrackets =~ /(.)u:l(a:?)r/))
		    {
			$letterbefore = $1;
			$vowel = $2;
		#	print "Lemma: $lemma\n";
			$PhonolSAM =~ s/${letterbefore}\@l\+a:r/${letterbefore}u:l\+${vowel}r/g; # partikular
			$PhonolCLX =~ s/${letterbefore}\@l\+a:r/${letterbefore}u:l\+${vowel}r/g;
		    }
		    

		    $PhonolSAM =~ s/i:\+i:/\+i:/g;
		    $PhonolCLX =~ s/i:\+i:/\+i:/g;

		    $PhonolSAM =~ s/i:\+\@$/\+\@/g; # loge, mane
		    $PhonolCLX =~ s/i:\+\@$/\+\@/g;

		    $PhonolSAM =~ s/i:\+e:/\+e:/g; # energ
		    $PhonolCLX =~ s/i:\+e:/\+e:/g;
		    
		 
		    if (($lemma =~ /losigkeit/) && ($PhonSylStBCLXwithoutbrackets =~ /lo:zIxkait/))
		    {
		#	print "losigkeit $PhonolSAM\n";  
			$PhonolSAM =~ s/#lo:s\+Ix#kait/#lo:z\+Ix#kait/g;
			$PhonolCLX =~ s/#lo:s\+Ix#kait/#lo:z\+Ix#kait/g;
			$PhonolSAM =~ s/#lo:s\+Ixkait/#lo:z\+Ixkait/g; # though it seems to be inconsistent
			$PhonolCLX =~ s/#lo:s\+Ixkait/#lo:z\+Ixkait/g;
		    }
		    
		    if (($lemma =~ /tel/) && ($PhonSylStBCLXwithoutbrackets =~ /t\@l/)) #achtel, neuntel, drittel
		    {
			$PhonolSAM =~ s/t#t\@l/t#\@l/g;
			$PhonolCLX =~ s/t#t\@l/t#\@l/g;
		    }

		    if (($lemma =~ /zig/) && ($PhonSylStBCLXwithoutbrackets =~ /tsIx/)) #achzig
		    {
			$PhonolSAM =~ s/t#tsIx/t#sIx/g;
			$PhonolCLX =~ s/t#tsIx/t#sIx/g;
		    }

		    if (($lemma =~ /zehn/) && ($PhonSylStBCLXwithoutbrackets =~ /tse:n/)) #achzig
		    {
			$PhonolSAM =~ s/t#tse:n/t#se:n/g;
			$PhonolCLX =~ s/t#tse:n/t#se:n/g;
		    }
 
		    
		    $newletterafter = "";
		     if (($lemma =~ /nahm/) && ($PhonSylStBCLXwithoutbrackets =~ /na:m(.?)/))
		     {
			$newletterafter = $letterafter = $1;
			
			if ($letterafter ne "\@")
			{
			    $newletterafter = "";  
			}
			$PhonolSAM =~ s/ne:m/na:m${newletterafter}/g;
			$PhonolCLX =~ s/ne:m/na:m${newletterafter}/g;
		    }


		    if (($lemma =~ /ilf/) && ($PhonSylStBCLXwithoutbrackets =~ /Ilf\@/))
		    {
			$PhonolSAM =~ s/Elf(?!\+\@)/Ilf\+\@/g;
			$PhonolCLX =~ s/Elf(?!\+\@)/Ilf\+\@/g;
			$PhonolSAM =~ s/Elf(?=\+\@)/Ilf/g;
			$PhonolCLX =~ s/Elf(?=\+\@)/Ilf/g;
			
		    }
		    
		    if (($lemma =~ /ilf/) && ($PhonSylStBCLXwithoutbrackets =~ /Ilf(?!\@)/) )
		    {
			$PhonolSAM =~ s/Elf/Ilf/g;
			$PhonolCLX =~ s/Elf/Ilf/g;
		    }

		    if (($lemma =~ /k[uü]nft/) && ($PhonSylStBCLXwithoutbrackets =~ /k([UY])nft/))
		     {
			 $vowel = $1;
			 
			 if ($lemma =~ /künfte/)
			 {
			     $PhonolSAM =~ s/kOm/kYnft\+\@/g;
			     $PhonolCLX =~ s/kOm/kYnft\+\@/g;
			 }
			 else
			 {
			     $PhonolSAM =~ s/kOm/k${vowel}nft/g;
			     $PhonolCLX =~ s/kOm/k${vowel}nft/g;
			 }
		     }

		    if (($lemma =~ /[kK]lang/) && ($PhonSylStBCLXwithoutbrackets =~ /klaN/))
		    {
			$PhonolSAM =~ s/klIN/klaN/g;
			$PhonolCLX =~ s/klIN/klaN/g;
		    }

		     if (($lemma =~ /[mM]ittag/) && ($PhonSylStBCLXwithoutbrackets =~ /mIta:k/))
		    {
			$PhonolSAM =~ s/mIt\@#ta:g/mI#ta:k/g;
			$PhonolCLX =~ s/mIt\@#ta:g/mI#ta:k/g;
		    }
		    

		     if (($lemma =~ /[mM]ontag/) && ($PhonSylStBCLXwithoutbrackets =~ /mo:nta:k/))
		    {
			$PhonolSAM =~ s/mo:nd#ta:g/mo:nta:k/g;
			$PhonolCLX =~ s/mo:nd#ta:g/mo:nta:k/g;
		    }
		    
		    if (($lemma =~ /[mM]orphi/) && ($PhonSylStBCLXwithoutbrackets =~ /mOrfi:(?!n)/))
		    {
			$PhonolSAM =~ s/mOrfi:n/mOrfi:/g;
			$PhonolCLX =~ s/mOrfi:n/mOrfi:/g;
		    }
		    
		    
		    if (($lemma =~ /[sS]ang/) && ($PhonSylStBCLXwithoutbrackets =~ /zaN/))
		    {
			$PhonolSAM =~ s/zIN\#zIN/zIN\#zaN/g || $PhonolSAM =~ s/zIN/zaN/g; # exception Singsang
			$PhonolCLX =~ s/zIN\#zIN/zIN\#zaN/g || $PhonolCLX =~ s/zIN/zaN/g;
		    }
		    
		    if (($lemma =~ /dorr/) && ($PhonSylStBCLXwithoutbrackets =~ /dOr/) )
		    {
			$PhonolSAM =~ s/dYr/dOr/g;
			$PhonolCLX =~ s/dYr/dOr/g;
		    }
		    
		    if (($lemma =~ /[sS]chatt([^e])/) && ($PhonSylStBCLXwithoutbrackets =~ /Sat([^\@])/) )
		     {
			 $PhonolSAM =~ s/Sat\@n/Sat/g;
			 $PhonolCLX =~ s/Sat\@n/Sat/g;
		     }
		    
		    if (($lemma =~ /[sS]char/) && ($PhonSylStBCLXwithoutbrackets =~ /Sa:r/) )
		     {
			 $PhonolSAM =~ s/Se:r/Sa:r/g;
			 $PhonolCLX =~ s/Se:r/Sa:r/g;
		     }
		    
		    if (($lemma =~ /[sS]cheitel/) && ($PhonSylStBCLXwithoutbrackets =~ /Sait\@l/) )
		     {
			 $PhonolSAM =~ s/Said\+\@l/Sait\+\@l/g;
			 $PhonolCLX =~ s/Said\+\@l/Sait\+\@l/g;
		     }

		    if (($lemma =~ /[sS]chlange/) && ($PhonSylStBCLXwithoutbrackets =~ /SlaN\@/) )
		    {
			$PhonolSAM =~ s/SlIN\+@/SlaN\@/g;
			$PhonolCLX =~ s/SlIN\+@/SlaN\@/g;
		    }
		    

		    if (($lemma =~ /[sS]chläng/) && ($PhonSylStBCLXwithoutbrackets =~ /SlEN/) )
		    {
			$PhonolSAM =~ s/SlIN/SlEN/g;
			$PhonolCLX =~ s/SlIN/SlEN/g;
		    } 
		    
		    if (($lemma =~ /[sS]chnee/) && ($PhonSylStBCLXwithoutbrackets =~ /Sne:/) )
		     {
			 $PhonolSAM =~ s/Snai/Sne:/g;
			 $PhonolCLX =~ s/Snai/Sne:/g;
		     }
		    if (($lemma =~ /chund/) && ($PhonSylStBCLXwithoutbrackets =~ /SUn([dt])/) )
		    {
			$letterafter = $1;
			$PhonolSAM =~ s/SInd/SUn${letterafter}/g;
			$PhonolCLX =~ s/SInd/SUn${letterafter}/g;
		    }
		    
		    if (($lemma =~ /[sS]chwun/) && ($PhonSylStBCLXwithoutbrackets =~ /SvU[Nn]/) ) # Schwung, Schwund
		     {
			$PhonolSAM =~ s/SvIN/SvUN/g;
			$PhonolCLX =~ s/SvIN/SvUN/g;
			$PhonolSAM =~ s/SvIn/SvUn/g;
			$PhonolCLX =~ s/SvIn/SvUn/g;
		     }

		    if (($lemma =~ /[sS]chwur/) && ($PhonSylStBCLXwithoutbrackets =~ /Svu:r/) )
		     {
			$PhonolSAM =~ s/Sv\|:r/Svu:r/g;
			$PhonolCLX =~ s/Sv\&:r/Svu:r/g;
		     }
		    
		    if (($lemma =~ /[sS]echz/) && ($PhonSylStBCLXwithoutbrackets =~ /zEx/) )
		     {
			$PhonolSAM =~ s/zEks/zEx/g;
			$PhonolCLX =~ s/zEks/zEx/g;
		     }
		    
		    
		    if (($lemma =~ /söhn/) && ($PhonSylStBCLXwithoutbrackets =~ /z&:n/) )
		     {
			$PhonolSAM =~ s/zy:n/z&:n/g;
			$PhonolCLX =~ s/zy:n/z&:n/g;
		     }
		    
		    
		    if (($lemma =~ /[sS]pr[ue]ng/) && ($PhonSylStBCLXwithoutbrackets =~ /Spr([UE])N/) )
		     {
			 $vowel = $1;
			 $PhonolSAM =~ s/SprIN/Spr${vowel}N/g;
			 $PhonolCLX =~ s/SprIN/Spr${vowel}N/g;
		     }
		    
		    if (($lemma =~ /[sS]tach/) && ($PhonSylStBCLXwithoutbrackets =~ /Stax/) )
		    {
			$PhonolSAM =~ s/StEx\+\@l/Stax\@l/g;
			$PhonolCLX =~ s/StEx\+\@l/Stax\@l/g;
		    }

		    

		    if (($lemma =~ /[Ss]t[aä]nd/) && ($PhonSylStBCLXwithoutbrackets =~ /St([aE])n([dt])/) ) # ständ, stand
		     {
			 $vowel = $1;
			 $letterafter = $2;
			 $PhonolSAM =~ s/Ste:/St${vowel}n${letterafter}/g;
			 $PhonolCLX =~ s/Ste:/St${vowel}n${letterafter}/g;
		     }
		    

		    if (($lemma =~ /[Ss]taub/) && ($PhonSylStBCLXwithoutbrackets =~ /Stau([pb])/))
		    {
			$letterafter = $1;
			$PhonolSAM =~ s/Sti:b/Stau${letterafter}/g;
			$PhonolCLX =~ s/Sti:b/Stau${letterafter}/g;
		    }
		    
		     if (($lemma =~ /[sS]täub/) && ($PhonSylStBCLXwithoutbrackets =~ /StOy([pb])/))
		     {
			$letterafter = $1;
			$PhonolSAM =~ s/Sti:b/StOy${letterafter}/g;
			$PhonolCLX =~ s/Sti:b/StOy${letterafter}/g;
		     }

		   # if (($lemma =~ /turz/) && ($PhonSylStBCLXwithoutbrackets =~ /StUrts/))
		   #  {
		#	$PhonolSAM =~ s/StYrts/StUrts/g;
		#	$PhonolCLX =~ s/StYrts/StUrts/g;
		  #   }
		    
		    if (($lemma =~ /[hH]ang/) && ($PhonSylStBCLXwithoutbrackets =~ /haN/) )
		    {
			$PhonolSAM =~ s/hEN/haN/g;
			$PhonolCLX =~ s/hEN/haN/g;
		    }

		    if (($lemma =~ /[zZ]w[aä]n/) && ($PhonSylStBCLXwithoutbrackets =~ /tsv([aE])N/) ) # 
		     {
			 $vowel = $1;
			 $PhonolSAM =~ s/tsvIN/tsv${vowel}N/g;
			 $PhonolCLX =~ s/tsvIN/tsv${vowel}N/g;
		     }

		    
		    if (($lemma =~ /tion/) && ($PhonSylStBCLXwithoutbrackets =~ /tsi:o:n/) )
		    {
			$PhonolSAM =~ s/ti:o:n/tsi:o:n/g;
			$PhonolCLX =~ s/ti:o:n/tsi:o:n/g;
			$PhonolSAM =~ s/t\+i:o:n/t\+si:o:n/g;
			$PhonolCLX =~ s/t\+i:o:n/t\+si:o:n/g;
		    }

		    if (($lemma =~ /ial/) && ($PhonSylStBCLXwithoutbrackets =~ /(\+?)i:a:?l/) )
		     {
			 #	 $letterafter = $1;
		#	 print "lemma: $lemma\n";
			 $PhonolSAM =~ s/ri:\@\+i:a:l/r\+i:a:l/g; # material, remove doube i
			 $PhonolCLX =~ s/ri:\@\+i:a:l/r\+i:a:l/g;
			 $PhonolSAM =~ s/\@r\+i:a:l/e:r\+i:a:l/g; # ministerial
			 $PhonolCLX =~ s/\@r\+i:a:l/e:r\+i:a:l/g;
			 $PhonolSAM =~ s/t\+i:a:l/t\+si:a:l/g; # ministerial
			 $PhonolCLX =~ s/t\+i:a:l/t\+si:a:l/g; # partial
			 
		    }
		    
		    if (($lemma =~ /ist/) && ($PhonSylStBCLXwithoutbrackets =~ /Ist/) )
		    {
			$PhonolSAM =~ s/i:\+Ist/\+Ist/g;
			$PhonolCLX =~ s/i:\+Ist/\+Ist/g;
		    }
		    

		    if (($lemma =~ /isch/) && ($PhonSylStBCLXwithoutbrackets =~ /IS/) )
		    {
			$PhonolSAM =~ s/i:\+IS/\+IS/g;
			$PhonolCLX =~ s/i:\+IS/\+IS/g;
			$PhonolSAM =~ s/f\@r\+IS/fo:r\+IS/g; # metaphorisch
			$PhonolCLX =~ s/f\@r\+IS/fo:r\+IS/g;
			
		    }

		    if (($PhonolCLX =~ /(.)a:\+(.)/) && ($PhonSylStBCLXwithoutbrackets !~ /$1a:$2/) &&
			($PhonSylStBCLXwithoutbrackets =~ /($1)($2)/)) #Zebroid, vaginal, Firmen...
		     {
			# print "a: $PhonolCLX\n";
			 $letterbefore = $1;
			 $letterafter = $2;
			 $PhonolSAM =~ s/da:\+r/dr/g; # special case "dar"
			 $PhonolCLX =~ s/da:\+r/dr/g;
			 $PhonolCLX =~ s/${letterbefore}a:\+${letterafter}/${letterbefore}\+${letterafter}/g;

			 # change ö to SAM notation, leprös
			 
			 $letterbefore =~ s/&/\Q\|\E/;
			 $letterafter =~ s/&/\Q\|\E/;

			 # print "in $PhonolSAM look for  $letterbefore $letterafter\n";
			 
			 $PhonolSAM =~ s/${letterbefore}a:\+${letterafter}/${letterbefore}\+${letterafter}/g;
			 $PhonolSAM =~ s/\\\|/\|/g;
		     }
		    

		    if (($PhonolCLX =~ /(.)u:(.)/) && ($PhonSylStBCLXwithoutbrackets !~ /\Q$1\Eu:\Q$2\E/) &&
			($PhonSylStBCLXwithoutbrackets =~ /(\Q$1\E)U(\Q$2\E)/)) # -ium
		     {
			 $letterbefore = $1;
			 $letterafter = $2;
		#	 print "u: $PhonolCLX $letterbefore $letterafter\n";
			
			# $PhonolSAM =~ s/da:\+r/dr/g; # special case "dar"
			# $PhonolCLX =~ s/da:\+r/dr/g;
			 $PhonolCLX =~ s/${letterbefore}u:${letterafter}/${letterbefore}U${letterafter}/g;

			 # change ö to SAM notation, leprös
			 
			 $letterbefore =~ s/&/\Q\|\E/;
			 $letterafter =~ s/&/\Q\|\E/;

			 # print "in $PhonolSAM look for  $letterbefore $letterafter\n";
			 
			 $PhonolSAM =~ s/${letterbefore}u:${letterafter}/${letterbefore}U${letterafter}/g;
			 $PhonolSAM =~ s/\\\|/\|/g;
		     }
		    
		    ##
		    if (($PhonolCLX =~ /(.)i:(.)/) && ($PhonSylStBCLXwithoutbrackets !~ /\Q$1\Ei:\Q$2\E/) &&
			($PhonSylStBCLXwithoutbrackets =~ /(\Q$1\E)I(\Q$2\E)/)) # -ium
		     {
			 $letterbefore = $1;
			 $letterafter = $2;
		#	 print "i: $PhonolCLX $letterbefore $letterafter\n";
			
			 $PhonolCLX =~ s/${letterbefore}i:${letterafter}/${letterbefore}I${letterafter}/g;

			 # change ö to SAM notation, leprös
			 
			 $letterbefore =~ s/&/\Q\|\E/;
			 $letterafter =~ s/&/\Q\|\E/;

			 # print "in $PhonolSAM look for  $letterbefore $letterafter\n";
			 
			 $PhonolSAM =~ s/${letterbefore}u:${letterafter}/${letterbefore}U${letterafter}/g;
			 $PhonolSAM =~ s/\\\|/\|/g;
		     }
		    
		    ##

		    

		    
		    if (($lemma =~ /arisch/) && ($PhonSylStBCLXwithoutbrackets =~ /a:rIS/) )
		    {
			$PhonolSAM =~ s/\@r\+IS/a:r\+IS/g; # kalendarisch
			$PhonolCLX =~ s/\@r\+IS/a:r\+IS/g;
		    }

		     if (($lemma =~ /(.)ul(.)/) && ($PhonSylStBCLXwithoutbrackets =~ /($1)u:l($2)/) )
		     {
			 $letterbefore = $1;
			 $letterafter = $2;
			 $PhonolSAM =~ s/${letterbefore}(y:|\@)l\+${letterafter}/${letterbefore}u:l\+${letterafter}/g; # kalkulieren
			 $PhonolCLX =~ s/${letterbefore}(y:|\@)l\+${letterafter}/${letterbefore}u:l\+${letterafter}/g; # kalkulieren, regul
			# $PhonolCLX =~ s/(y:|\@)l\+i:r/u:l\+i:r/g;
		     }

		    
		  #  if (($lemma =~ /[vV]illen/) && ($PhonSylStBCLXwithoutbrackets =~ /vIl\@n/) )
		   # {
		#	$PhonolSAM =~ s/vIla:\+/vIl/g;
		#	$PhonolCLX =~ s/vIla:\+/vIl/g;
		 #   }

		    if (($lemma =~ /[Zz]ipf/) && ($PhonSylStBCLXwithoutbrackets =~ /tsIpf/) )
		    {
			$PhonolSAM =~ s/tsapf/tsIpf/g;
			$PhonolCLX =~ s/tsapf/tsIpf/g;
		    }
		    if (($lemma =~ /[Zz]und/) && ($PhonSylStBCLXwithoutbrackets =~ /tsUnd/) )
		    {
			$PhonolSAM =~ s/tsYnd/tsUnd/g;
			$PhonolCLX =~ s/tsYnd/tsUnd/g;
		    }
		    
		    if (($lemma =~ /[Zz]wack/) && ($PhonSylStBCLXwithoutbrackets =~ /tsvak/) )
		    {
			$PhonolSAM =~ s/tsvIk/tsvak/g;
			$PhonolCLX =~ s/tsvIk/tsvak/g;
		    }

		  #  $newletterafter = "";

				    
		    if (($lemma =~ /[Ww]ahl/) && ($PhonSylStBCLXwithoutbrackets =~ /va:l/) )
		    {
			$PhonolSAM =~ s/vE:l/va:l/g;
			$PhonolCLX =~ s/vE:l/va:l/g;
		    }

		    if (($lemma =~ /[Ww]end/) && ($PhonSylStBCLXwithoutbrackets =~ /vEn([dt])/) )
		    {
			$letterafter = $1;
			$PhonolSAM =~ s/vInd/vEn${letterafter}/g;
			$PhonolCLX =~ s/vInd/vEn${letterafter}/g;
		    }

		     if (($lemma =~ /[Ww]itt/) && ($PhonSylStBCLXwithoutbrackets =~ /vIt/) )
		    {
			$PhonolSAM =~ s/vEt/vIt/g;
			$PhonolCLX =~ s/vEt/vIt/g;
		    }

		    if (($lemma =~ /[Ww]uchs/) && ($PhonSylStBCLXwithoutbrackets =~ /vu:ks/) )
		    {
			$PhonolSAM =~ s/vaks/vu:ks/g;
			$PhonolCLX =~ s/vaks/vu:ks/g;
		    }
		    
		    
		    if (($lemma =~ /[äÄ]lt/) && ($PhonSylStBCLXwithoutbrackets =~ /Elt/) )
		    {
			$PhonolSAM =~ s/alt/Elt/g;
			$PhonolCLX =~ s/alt/Elt/g;
		    }

		    if (($lemma =~ /[nN]äh/) && ($PhonSylStBCLXwithoutbrackets =~ /nE:/) )
		    {
			$PhonolSAM =~ s/na:/nE:/g;
			$PhonolCLX =~ s/na:/nE:/g;
		    }
		    
		    if (($lemma =~ /[nN]ahr/) && ($PhonSylStBCLXwithoutbrackets =~ /na:r/) )
		    {
			$PhonolSAM =~ s/nE:r/na:r/g;
			$PhonolCLX =~ s/nE:r/na:r/g;
		    }
		    
		    
		    if (($lemma =~ /uss/) && ($PhonSylStBCLXwithoutbrackets =~ /Us/) )
		    {
			$PhonolSAM =~ s/i:s/Us/g;
			$PhonolCLX =~ s/i:s/Us/g;
		    }

		    
		    if (($lemma =~ /dräng/) && ($PhonSylStBCLXwithoutbrackets =~ /drEN/) )
		    {
			$PhonolSAM =~ s/\#drIN/\#drEN/g;
			$PhonolCLX =~ s/\#drIN/\#drEN/g;
		    }
		     if (($lemma =~ /[dDtT]rift/) && ($PhonSylStBCLXwithoutbrackets =~ /([td])rIft/) )
		    {
			$letterbefore = $1;
			$PhonolSAM =~ s/traib/${letterbefore}rIft/g;
			$PhonolCLX =~ s/traib/${letterbefore}rIft/g;
			$PhonolSAM =~ s/trEf/trIf/g; #triftig < tref
			$PhonolCLX =~ s/trEf/trIf/g;
		    }

		    
		    if (($lemma =~ /[Tt]at/) && ($PhonSylStBCLXwithoutbrackets =~ /ta:t/) )
		    {
			$PhonolSAM =~ s/tu:/ta:t/g;
			$PhonolCLX =~ s/tu:/ta:t/g;
		    }
		     if (($lemma =~ /[Tt]ät/) && ($PhonSylStBCLXwithoutbrackets =~ /tE:/) )
		    {
			$PhonolSAM =~ s/tu:/tE:t/g;
			$PhonolCLX =~ s/tu:/tE:t/g;
		    }

		    
		    if (($lemma =~ /[Tt]od/) && ($PhonSylStBCLXwithoutbrackets =~ /to:d/) )
		    {
			$PhonolSAM =~ s/to:t/to:d/g;
			$PhonolCLX =~ s/to:t/to:d/g;
		    }

		    if (($lemma =~ /[Vv]iertel/) && ($PhonSylStBCLXwithoutbrackets =~ /fIrt\@l/) )
		    {
			$PhonolSAM =~ s/fi:r#t\@l/fIr#t\@l/g;
			$PhonolCLX =~ s/fi:r#t\@l/fIr#t\@l/g;
		    }
		    
		    if (($lemma =~ /[Rr]ät/) && ($PhonSylStBCLXwithoutbrackets =~ /rE:t/) )
		    {
			$PhonolSAM =~ s/ra:t/rE:t/g;
			$PhonolCLX =~ s/ra:t/rE:t/g;
		    }

		    if (($lemma =~ /[Rr]echen/) && ($PhonSylStBCLXwithoutbrackets =~ /rEx\@n/) )
		    {
			$PhonolSAM =~ s/rExn/rEx\@n/g;
			$PhonolCLX =~ s/rExn/rEx\@n/g;
		    }

		    if (($lemma =~ /[rR]itt/) && ($PhonSylStBCLXwithoutbrackets =~ /(.)rIt/) )
		    {
			$letterbefore = $1;
			if ($letterbefore eq "t")
			{
			    $PhonolSAM =~ s/tre:t/trIt/g;
			    $PhonolCLX =~ s/tre:t/trIt/g;  
			}
			else
			{
			    $PhonolSAM =~ s/rait/rIt/g;
			    $PhonolCLX =~ s/rait/rIt/g;
			}
		    }
		    
		    if (($lemma =~ /[rR]ütt/) && ($PhonSylStBCLXwithoutbrackets =~ /rYt(?!\@l)/) ) # Zerrüttung
		    {
			$PhonolSAM =~ s/rYt\@l/rYt/g;
			$PhonolCLX =~ s/rYt\@l/rYt/g;
		    }

		    
		     if (($lemma =~ /[aA]ufwand/) && ($PhonSylStBCLXwithoutbrackets =~ /vant/) )
		    {
			$PhonolSAM =~ s/vInd/vant/g;
			$PhonolCLX =~ s/vInd/vant/g;
		    }
		    
		    if (($lemma =~ /[wW]ill/) && ($PhonSylStBCLXwithoutbrackets =~ /vIl(.)/) )
		    {
			$newletterafter = $letterafter = $1;
			if ($letterafter ne "\@")
			{
			    $newletterafter = "";
			}
			$PhonolSAM =~ s/vOl/vIl${newletterafter}/g;
			$PhonolCLX =~ s/vOl/vIl${newletterafter}/g;
		    }
		    
		    if (($lemma =~ /[wW][uü]rf/) && ($PhonSylStBCLXwithoutbrackets =~ /v([UY])rf/) )
		    {
			$vowel = $1;
			$PhonolSAM =~ s/vErf/v${vowel}rf/g;
			$PhonolCLX =~ s/vErf/v${vowel}rf/g;
		    }
		    
		    if (($lemma =~ /[Zz][uüö]g/)
			&& ($PhonSylStBCLXwithoutbrackets =~ /ts([yu\&]:)([gk])/) )
		    {
			$vowel = $1;
			$letterafter = $2;
			$PhonolCLX =~ s/tsi:/ts${vowel}${letterafter}/g;

			$vowel =~ s/&/\Q\|\E/;
			$PhonolSAM =~ s/tsi:/ts${vowel}${letterafter}/g;
			$PhonolSAM =~ s/\\\|/\|/g;
		    }
		    
		    if (($lemma =~ /[Zz][uü]cht/) && ($PhonSylStBCLXwithoutbrackets =~ /ts([YU])xt/) )
		    {
			$vowel = $1;
			$PhonolSAM =~ s/tsi:/ts${vowel}xt/g;
			$PhonolCLX =~ s/tsi:/ts${vowel}xt/g;
		    }

		    if (($lemma =~ /[Zz]watz/) && ($PhonSylStBCLXwithoutbrackets =~ /tsvats/) )
		    {
			$PhonolSAM =~ s/tsvEts/tsvats/g;
			$PhonolCLX =~ s/tsvEts/tsvats/g;
		    }

		     if (($lemma =~ /[Zz]wie/) && ($PhonSylStBCLXwithoutbrackets =~ /tsvi:/) )
		    {
			$PhonolSAM =~ s/tsvai/tsvi:/g;
			$PhonolCLX =~ s/tsvai/tsvi:/g;
		    }
		    
		    if (($lemma =~ /[Aa]benteur/) && ($PhonSylStBCLXwithoutbrackets =~ /a:b\@ntOyr/) )
		    {
			$PhonolSAM =~ s/a:b\@ntOy\@r/a:b\@ntOyr/g;
			$PhonolCLX =~ s/a:b\@ntOy\@r/a:b\@ntOyr/g;
		    }

		    if ($lemma =~ /abessinisch/) # mistake
		    {
			$PhonolSAM =~ s/ap\#Es\+i\:nIS/abEsi\:nIS/g;
			$PhonolCLX =~ s/ap\#Es\+i\:nIS/abEsi\:nIS/g;
		    }

		     if (($lemma =~ /hak/) && ($PhonSylStBCLXwithoutbrackets =~ /ha:k/) ) # mistake
		    {
			$PhonolSAM =~ s/hak/ha:k/g;
			$PhonolCLX =~ s/hak/ha:k/g;
		    }

		    if (($lemma =~ /schuf/) && ($PhonolSAMwithoutdel =~ /Si:b/) ) # mistake?
		    {
			$PhonolSAM =~ s/Si:b/SUft/g;
			$PhonolCLX =~ s/Si:b/SUft/g;
		    }


		    if (($lemma =~ /bränd/) && ($PhonSylStBCLXwithoutbrackets =~ /brEnt/) )
		    {
			$PhonolSAM =~ s/#brEn#/#brEnt#/g;
			$PhonolCLX =~ s/#brEn#/#brEnt#/g;
		    }
		    
                   # Auslautverhärtung again
		    $stransformeddel = $PhonolCLX;
		    # print "transformeddel again: $stransformeddel\n";
		    $stransformeddel =~ s/d#/t/;
		    $stransformeddel =~ s/z#/s/;
		    $stransformeddel =~ s/Ig#/Ik/g;
		    $stransformeddel =~ s/\+Ix#lIx/\+Ik#lIx/g; # elendiglich
		    $stransformeddel =~ s/g#/k/;
		    $stransformeddel =~ s/b#/p/;

		    $stransformeddel =~ s/Ig\+/Ix/;
		    
		    $stransformeddel =~ s/d$/t/;
		    $stransformeddel =~ s/z$/s/;
		    $stransformeddel =~ s/Ig$/Ix/;
		    $stransformeddel =~ s/g$/k/;
		    $stransformeddel =~ s/b$/p/;

		    $stransformeddelshortvowel =  $stransformeddel;
		    $stransformeddelshortvowel =~ s/a:/a/;
		   # $stransformeddelshortvowel =~ s/i:/I/;
		    
		    
		    $stransformeddelwoschwa = $stransformeddel;
		   #  print "1 zw transformeddelwoschwa:  $stransformeddelwoschwa\n";
		    
		    # $stransformeddelwoschwa =~ s/\@\#/\#/g;
		    
		    $stransformeddelwoschwa =~ s/([^\\\#]{2,})\@\#/$1\#/g; # at least two letters before (exclude #b@# and #g@#)
		    
		    $stransformeddelwoschwa =~ s/\+\#/\#/g;

		    #$stransformeddelwoschwa =~ s/\@\+/\+/g; # amusisch, einfarbig

		    $stransformeddelwoschwa =~ s/\@\+(?!n\#)/\+/g; # amusisch, einfarbig, erst(e);
		    #  not e+n (Fuge, interfix)
		    
		    $stransformeddelwoschwa =~ s/t\+\+n/t\+\@\+n/g; # not t+e+n


		    $stransformeddelwoschwa =~ s/(?<!\@n\+)\@l\+/l\+/g; # Entwicklung, würflig
		    $stransformeddelwoschwa =~ s/\@n\+\@l/\+\@l/g; # Abbröckelung, Zipfelmütze

		    $stransformeddelwoschwa =~ s/(?<![tf])\@n\+\@r/\+\@r/g; # Verknöcherung
		    
		    
		    $stransformeddelwoschwa =~ s/\@n\+/n\+/g; # zeichnung, gärtner
		    $stransformeddelwoschwa =~ s/([^\+])\@r\+([^s])/$1r\+$2/g; # poltrig, exclude anders and +er+
		    
		    
		    # and then again Habseligkeit b -> p
		    $stransformeddelwoschwa =~ s/d#/t/g;
		    $stransformeddelwoschwa =~ s/z#/s/g;
		    $stransformeddelwoschwa =~ s/Ig#/Ix/g;
		    #$stransformeddelwoschwa =~ s/Ix#/Ig/g;
		    $stransformeddelwoschwa =~ s/g#/k/g;
		    $stransformeddelwoschwa =~ s/b#/p/g;

		    #$stransformeddelwoschwa =~ s/Ig\+/Ix/g;
		    $stransformeddelwoschwa =~ s/\+Ix\+/Ig/g;
		    $stransformeddelwoschwa =~ s/tIx\+/tIg/g; # Leibhaftige
		    
		    $stransformeddel =~ s/\+//g; 
		    $stransformeddel =~ s/\#//g;

		    $stransformeddelshortvowel =~ s/\+//g; 
		    $stransformeddelshortvowel =~ s/\#//g;

		    #only here
		    $stransformeddelwoschwashortvowel =  $stransformeddelwoschwa;
		    $stransformeddelwoschwashortvowel =~ s/a:/a/;

		    $stransformeddelwoschwashortvowel =~ s/\+//g;
		    $stransformeddelwoschwashortvowel =~ s/\#//g;

		    $stransformeddelwoschwa =~ s/\+//g;
		    $stransformeddelwoschwa =~ s/\#//g;

		   # print "zw transformeddelwoschwa:  $stransformeddelwoschwa\n";
		    
		   # print "transformed:  $stransformed , tranformeddel: $stransformeddel ,
		#	   wo: $PhonolCLXwithoutdel , wob: $PhonSylStBCLXwithoutbrackets \n";

		    
		   # print "transformeddel 2: $stransformeddel transformed:  $stransformed  wob: $PhonSylStBCLXwithoutbrackets \n";
		    
		    if ($stransformeddel eq $PhonSylStBCLXwithoutbrackets)
		    {
			
		#	print "*2 Auslautverhärtung: $stransformed\n"; # Zusatzzahl
			$PhonolSAM =~ s/\+\+/\+/g;
			$PhonolCLX =~ s/\+\+/\+/g;
			
			$PhonolSAM =~ s/d#/t#/;
			$PhonolSAM =~ s/z#/s#/;
			$PhonolSAM =~ s/Ig#/Ik#/;
			$PhonolSAM =~ s/g#/k#/;
			$PhonolSAM =~ s/b#/p#/;
			$PhonolCLX =~ s/d#/t#/;
			$PhonolCLX =~ s/z#/s#/;
			$PhonolCLX =~ s/Ig#/Ik#/;
			$PhonolCLX =~ s/g#/k#/;
			$PhonolCLX =~ s/b#/p#/;
			$PhonolSAM =~ s/Ig\+/Ix\+/;
			$PhonolCLX =~ s/Ig\+/Ix\+/;

			$PhonolSAM =~ s/\+Ix#lIx/\+Ik#lIx/g; # elendiglich
			$PhonolCLX =~ s/\+Ix#lIx/\+Ik#lIx/g; # elendiglich
			
			$PhonolSAM =~ s/d$/t/;
			$PhonolSAM =~ s/z$/s/;
			$PhonolSAM =~ s/Ig$/Ix/;
			$PhonolSAM =~ s/g$/k/;
			$PhonolSAM =~ s/b$/p/;
			$PhonolCLX =~ s/d$/t/;
			$PhonolCLX =~ s/z$/s/;
			$PhonolCLX =~ s/Ig$/Ix/;
			$PhonolCLX =~ s/g$/k/;
			$PhonolCLX =~ s/b$/p/;
			$sLinephoncopy2 = "$lemma$before$PhonSylStBCLX$between\\$PhonolSAM\\$PhonolCLX";
			$horthphonsurface{$key} = $sLinephoncopy2;

			next KEY;
			
		    }
		    
		    if ($stransformeddelshortvowel eq $PhonSylStBCLXwithoutbrackets)
		    {
		#	print "Short vowel/Auslautverhärtung: $stransformed\n"; # Zusatzzahl
			$PhonolSAM =~ s/d#/t#/;
			$PhonolSAM =~ s/z#/s#/;
			$PhonolSAM =~ s/Ig#/Ik#/;
			$PhonolSAM =~ s/g#/k#/;
			$PhonolSAM =~ s/b#/p#/;
			$PhonolCLX =~ s/d#/t#/;
			$PhonolCLX =~ s/z#/s#/;
			$PhonolCLX =~ s/Ig#/Ik#/;
			$PhonolCLX =~ s/g#/k#/;
			$PhonolCLX =~ s/b#/p#/;
			$PhonolSAM =~ s/Ig\+/Ix\+/;
			$PhonolCLX =~ s/Ig\+/Ix\+/;

			$PhonolSAM =~ s/\+Ix#lIx/\+Ik#lIx/g; # elendiglich
			$PhonolCLX =~ s/\+Ix#lIx/\+Ik#lIx/g; # elendiglich
			
			$PhonolSAM =~ s/d$/t/;
			$PhonolSAM =~ s/z$/s/;
			$PhonolSAM =~ s/Ig$/Ix/;
			$PhonolSAM =~ s/g$/k/;
			$PhonolSAM =~ s/b$/p/;
			$PhonolCLX =~ s/d$/t/;
			$PhonolCLX =~ s/z$/s/;
			$PhonolCLX =~ s/Ig$/Ix/;
			$PhonolCLX =~ s/g$/k/;
			$PhonolCLX =~ s/b$/p/;
			
			$PhonolSAM =~ s/a:/a/;
			$PhonolCLX =~ s/a:/a/;
		#	$PhonolSAM =~ s/i:/I/;
			#	$PhonolCLX =~ s/i:/I/;

			$sLinephoncopy2 = "$lemma$before$PhonSylStBCLX$between\\$PhonolSAM\\$PhonolCLX";
			$horthphonsurface{$key} = $sLinephoncopy2;

			next KEY;
		    }


		    if ($stransformeddelwoschwa eq $PhonSylStBCLXwithoutbrackets)
		    {
		#	print "2* Schwa Auslautverhärtung: $stransformeddelwoschwa\n";
						
			$PhonolSAM =~ s/([^\\\#]{2,})\@#/$1#/g;
			$PhonolCLX =~ s/([^\\\#]{2,})\@#/$1#/g;

			$PhonolSAM =~ s/\+#/#/g;
			$PhonolCLX =~ s/\+#/#/g;

			$PhonolSAM =~ s/\@\+(?!n\#)/\+/g; # amusisch, einfarbig, wangig
			$PhonolCLX =~ s/\@\+(?!n\#)/\+/g; # amusisch, einfarbig

		#	$PhonolSAM =~ s/\@\+/\+/g; # amusisch, einfarbig
		#	$PhonolCLX =~ s/\@\+/\+/g; # amusisch, einfarbig

			$PhonolSAM =~ s/t\+\+n/t\+\@\+n/g; # not t+e+n
			$PhonolCLX =~ s/t\+\+n/t\+\@\+n/g; # not t+e+n
			
			$PhonolSAM =~ s/(?<!\@n\+)\@l\+/l\+/g; # Entwicklung, würflig
			$PhonolCLX =~ s/(?<!\@n\+)\@l\+/l\+/g; # Entwicklung

			$PhonolSAM =~ s/\@n\+\@l/\+\@l/g; # Abbröckelung, Zipfelmütze
			$PhonolCLX =~ s/\@n\+\@l/\+\@l/g; # Abbröckelung, Zipfelmütze

			$PhonolSAM =~ s/(?<![tf])\@n\+\@r/\+\@r/g; # Verknöcherung
			$PhonolCLX =~ s/(?<![tf])\@n\+\@r/\+\@r/g; # Verknöcherung
			
			$PhonolSAM =~ s/\@n\+/n\+/g; # Landschaftsgärtner
			$PhonolCLX =~ s/\@n\+/n\+/g; # 

			$PhonolSAM =~ s/([^\+])\@r\+([^s])/$1r\+$2/g; # polterig
			$PhonolCLX =~ s/([^\+])\@r\+([^s])/$1r\+$2/g; # polterig

			$PhonolSAM =~ s/\+\+/\+/g;
			$PhonolCLX =~ s/\+\+/\+/g;
						
			$PhonolSAM =~ s/d#/t#/g;
			$PhonolSAM =~ s/z#/s#/g;
			$PhonolSAM =~ s/Ig#/Ix#/g;
			$PhonolSAM =~ s/g#/k#/g;
			$PhonolSAM =~ s/b#/p#/g;
			$PhonolSAM =~ s/v#/f#/g;
			$PhonolCLX =~ s/d#/t#/g;
			$PhonolCLX =~ s/z#/s#/g;
			$PhonolCLX =~ s/Ig#/Ix#/g;
			$PhonolCLX =~ s/g#/k#/g;
			$PhonolCLX =~ s/b#/p#/g;
			$PhonolCLX =~ s/v#/f#/g;
		
			#$PhonolSAM =~ s/Ig\+/Ix\+/g;
			#$PhonolCLX =~ s/Ig\+/Ix\+/g;#

			$PhonolSAM =~ s/([\+t])Ix\+/$1Ig\+/g;
			$PhonolCLX =~ s/([\+t])Ix\+/$1Ig\+/g;

			$PhonolSAM =~ s/g\+s/k\+s/g;
			$PhonolCLX =~ s/g\+s/k\+s/g;

			$PhonolSAM =~ s/d$/t/;
			$PhonolSAM =~ s/z$/s/;
			$PhonolSAM =~ s/Ig$/Ix/;
			$PhonolSAM =~ s/g$/k/;
			$PhonolSAM =~ s/b$/p/;
			$PhonolSAM =~ s/v$/f/;
			$PhonolCLX =~ s/d$/t/;
			$PhonolCLX =~ s/z$/s/;
			$PhonolCLX =~ s/Ig$/Ix/;
			$PhonolCLX =~ s/g$/k/;
			$PhonolCLX =~ s/b$/p/;
			$PhonolCLX =~ s/v$/f/;

			#only here
		#	$PhonolSAM =~ s/a:/a/;
		#	$PhonolCLX =~ s/a:/a/;
			
			$sLinephoncopy2 = "$lemma$before$PhonSylStBCLX$between\\$PhonolSAM\\$PhonolCLX";
			$horthphonsurface{$key} = $sLinephoncopy2;

			$unchangedcounter++;
			next KEY;
		    }
		    ####
		    
		    if ($stransformeddelwoschwashortvowel eq $PhonSylStBCLXwithoutbrackets) # statuarisch
		    {
		#	print "2 short vowel Schwa Auslautverhärtung: $stransformeddelwoschwashortvowel $PhonSylStBCLXwithoutbrackets 	$PhonolSAM\n";
						
			$PhonolSAM =~ s/([^\\\#]{2,})\@#/$1#/g;
			$PhonolCLX =~ s/([^\\\#]{2,})\@#/$1#/g;

			$PhonolSAM =~ s/\+#/#/g;
			$PhonolCLX =~ s/\+#/#/g;

			$PhonolSAM =~ s/\@\+(?!n\#)/\+/g; # amusisch, einfarbig, wangig
			$PhonolCLX =~ s/\@\+(?!n\#)/\+/g; # amusisch, einfarbig

		#	$PhonolSAM =~ s/\@\+/\+/g; # amusisch, einfarbig
		#	$PhonolCLX =~ s/\@\+/\+/g; # amusisch, einfarbig

			$PhonolSAM =~ s/t\+\+n/t\+\@\+n/g; # not t+e+n
			$PhonolCLX =~ s/t\+\+n/t\+\@\+n/g; # not t+e+n
			
			$PhonolSAM =~ s/(?<!\@n\+)\@l\+/l\+/g; # Entwicklung, würflig
			$PhonolCLX =~ s/(?<!\@n\+)\@l\+/l\+/g; # Entwicklung

			$PhonolSAM =~ s/\@n\+\@l/\+\@l/g; # Abbröckelung, Zipfelmütze
			$PhonolCLX =~ s/\@n\+\@l/\+\@l/g; # Abbröckelung, Zipfelmütze

			$PhonolSAM =~ s/(?<![tf])\@n\+\@r/\+\@r/g; # Verknöcherung
			$PhonolCLX =~ s/(?<![tf])\@n\+\@r/\+\@r/g; # Verknöcherung
			
			$PhonolSAM =~ s/\@n\+/n\+/g; # Landschaftsgärtner
			$PhonolCLX =~ s/\@n\+/n\+/g; # 

			$PhonolSAM =~ s/([^\+])\@r\+([^s])/$1r\+$2/g; # polterig
			$PhonolCLX =~ s/([^\+])\@r\+([^s])/$1r\+$2/g; # polterig

			$PhonolSAM =~ s/\+\+/\+/g;
			$PhonolCLX =~ s/\+\+/\+/g;
						
			$PhonolSAM =~ s/d#/t#/g;
			$PhonolSAM =~ s/z#/s#/g;
			$PhonolSAM =~ s/Ig#/Ix#/g;
			$PhonolSAM =~ s/g#/k#/g;
			$PhonolSAM =~ s/b#/p#/g;
			$PhonolSAM =~ s/v#/f#/g;
			$PhonolCLX =~ s/d#/t#/g;
			$PhonolCLX =~ s/z#/s#/g;
			$PhonolCLX =~ s/Ig#/Ix#/g;
			$PhonolCLX =~ s/g#/k#/g;
			$PhonolCLX =~ s/b#/p#/g;
			$PhonolCLX =~ s/v#/f#/g;
		
			#$PhonolSAM =~ s/Ig\+/Ix\+/g;
			#$PhonolCLX =~ s/Ig\+/Ix\+/g;#

			$PhonolSAM =~ s/([\+t])Ix\+/$1Ig\+/g;
			$PhonolCLX =~ s/([\+t])Ix\+/$1Ig\+/g;

			$PhonolSAM =~ s/g\+s/k\+s/g;
			$PhonolCLX =~ s/g\+s/k\+s/g;

			$PhonolSAM =~ s/d$/t/;
			$PhonolSAM =~ s/z$/s/;
			$PhonolSAM =~ s/Ig$/Ix/;
			$PhonolSAM =~ s/g$/k/;
			$PhonolSAM =~ s/b$/p/;
			$PhonolSAM =~ s/v$/f/;
			$PhonolCLX =~ s/d$/t/;
			$PhonolCLX =~ s/z$/s/;
			$PhonolCLX =~ s/Ig$/Ix/;
			$PhonolCLX =~ s/g$/k/;
			$PhonolCLX =~ s/b$/p/;
			$PhonolCLX =~ s/v$/f/;

			#only here
			$PhonolSAM =~ s/a:/a/;
			$PhonolCLX =~ s/a:/a/;
			
			$sLinephoncopy2 = "$lemma$before$PhonSylStBCLX$between\\$PhonolSAM\\$PhonolCLX";
			$horthphonsurface{$key} = $sLinephoncopy2;

		#	$unchangedcounter++;
			next KEY;
		    }

		    ####


		    
		    if ($PhonolSAM ne $PhonolSAMold)
		    {
			$sLinephoncopy2 = "$lemma$before$PhonSylStBCLX$between\\$PhonolSAM\\$PhonolCLX";
			$horthphonsurface{$key} = $sLinephoncopy2;
			next KEY;
		    }

		    else
		    {
			# add to Checkfile
			open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
			print AUSGABE "$sLinephon\n";
			# change and add .......
			
			#nothing could be done, so just add
			$horthphonsurface{$key} = $sLinephoncopy1;
		    }
		}
	    }
	    else
	    {
		print "Could not process Line $sLinephon but add the entry as it is.\n";
		$unchangedcounter++;
		$horthphonsurface{$key} = $sLinephon;
	    }
	    
	}
    # close everything
    $hashsize = keys %horthphonsurface;  
 
    undef $db1;
    undef $dbout;
    untie (%hphon);
    untie (%horthphonsurface);

    # return filename

    print "valid lines of inputfile: $linecounter , unchanged: $unchangedcounter , number of entries in hash: $hashsize\n";
    return ($sortphonoutputfile);
}

sub output_of_tied_hash {
    my ($inputhashfile, $outputtextfile) = @_;
    my (%hinput,
	@keys,
	$key,
	$value,
	@valuearray,
	$db,
	);

   $db = tie (%hinput, 'MLDBM' , $inputhashfile, O_RDONLY, 0644, $DB_BTREE);

    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    
    open (AUSGABE, ">$outputtextfile") || die "Fehler! ";
    @keys = natkeysort { $_} keys %hinput;

    foreach $key (@keys)
	{
	    $value = $hinput{$key};
            print AUSGABE "$key\\$value\n";
	}
    close AUSGABE;
    undef $db;   
    untie (%hinput);

# later put in the path to the file to the returnValue
    return ("$outputtextfile");
}
