=pod

=head1  Skript: OrthCELEX  

Version 1.0                                                

=head1 Author 

Petra C. Steiner, Institut fuer Deutsche Sprache      
steiner@ids-mannheim.de                        

=head1 CALL                                                        

perl OrthCELEXforgsl.pl                                            

=head1 Description  

This is a simple Perl script for the conversion of CELEX gsl.cd to a modernized version.                  
                                                             
 Quick start:                                              
                                                             
 1. Install Perl 5.14 for Linux                                
 2. Put the Input files into the same folder as this program 
 3. Install all missing packages                             
 4. Start the program by "perl OrthCELEXgsl.pl"                 
                                                             
  Input Files:                                               
  gsl.cd and GOL.CD of the CELEX database                    
  within the same folder                                     
                                                             
 Files generated:                                            
 GSOLoutputintermediate: revised umlauts and sz of lemmas    
 GSOLout: above plus revised morphological analyses          
 GSOLoutneworthography: GSOL transformed to modern spelling  
                                                             
 Checkfile: some words whose recycling could go wrong        
            (currently no problems)                          
 Doubleconsonants: some candidate substitution rules         
   (currently only those who are incorrectly produced,       
    do not include them to the rules)                        
                                                             
 Hash files for internal usage:                              
 gslhash  GSOLintermediatehash  GSOLoutputhash                
 GSOLoutputreformedhash  GOLhash                             
                                                             
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

use Sort::Key::Natural qw(natkeysort);

BEGIN 
{
    our $start_run = time(); 
}

$| = 1;

my($nReturnValueFilename1,
   $nReturnValueFilename2,
   $nReturnValueFilename3,
   $smorphhashFilename,
   $sorthhashFilename,
   $sFilename,
   $smorphwithorthFilename,
   $db,
   %hfile);

$smorphhashFilename = "gslhash";

# if gslhash has been generated use this file (later: no consequences)

if (-e $smorphhashFilename)
{
    print "\n Loading hash file of gsl\n";
    $db = tie (%hfile, 'MLDBM', "$smorphhashFilename", 
	 O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $smorphhashFilename";
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    undef $db;
    untie (%hfile); 
}

else
# create it

{
    $sFilename = "gsl.cd";

    if ( ! -e $sFilename) {die "$sFilename does not exist."};
    $nReturnValueFilename1 = put_indexedfile_in_hash($sFilename, $smorphhashFilename);
    $db = tie (%hfile, 'MLDBM', "$smorphhashFilename", 
	       O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $smorphhashFilename";
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

$smorphwithorthFilename = "GSOLintermediatehash";

$nReturnValueFilename3 = create_data_with_diacritics($smorphhashFilename, $sorthhashFilename, $smorphwithorthFilename);

$sFilename = "GSOLoutputintermediate";
print "Output file:  $sFilename.\n\n";

$nReturnValueFilename2 = output_of_tied_hash($nReturnValueFilename3, $sFilename);

$sFilename = "GSOLoutputhash";

$nReturnValueFilename3 = change_morphs_in_structures($smorphwithorthFilename, $sFilename);

$sFilename = "GSOLoutput";
$nReturnValueFilename2 = output_of_tied_hash($nReturnValueFilename3, $sFilename);

print "Output file: $sFilename.\n\n";

$sFilename = "GSOLoutputreformedhash";

$nReturnValueFilename2 = change_to_new_orthography($nReturnValueFilename3, $sFilename);




$sFilename = "GSOLoutputneworthography";
$nReturnValueFilename3 = output_of_tied_hash($nReturnValueFilename2, $sFilename);
print "Output in $sFilename.\n\n";

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


# Das Hashergebnis in eine Datei schreiben
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


# creates morphological information with diacritics and special characters

sub create_data_with_diacritics 
{
    my ($smorphinputfile, $sorthinputfile, $sorthmorphoutputfile) = @_;
    my (%hmorph,
	%horth,
	%horthmorph,
	$key,
	@keys,
	$nReturnValue1,
	$sLinemorph,
	$sLineorth,
	$sLineorthmorph,
	$linecounter,
	$unchangedcounter,
	$index,
	$entry,
	$hashsize,
	$db1,
	$db2,
	$dbout,
	$checkfile,
	);
    print "\nCreate data with diacritics.\n";


    $db1 = tie (%hmorph, 'MLDBM', "$smorphinputfile", O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $smorphinputfile";
    $db2 = tie (%horth, 'MLDBM', "$sorthinputfile", O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $sorthinputfile";
# Das Hashergebnis in eine Datei schreiben
    Dumper($db1->{DB});

    $db1->{DB}->Filter_Push('utf8');

    Dumper($db2->{DB});

    $db2->{DB}->Filter_Push('utf8');

    $dbout = tie (%horthmorph, 'MLDBM', "$sorthmorphoutputfile",  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
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
	    $sLinemorph = $hmorph{$key};
	    $sLineorth = $horth{$key};

# test if there is a special character
	    if ($sLineorth =~ /.*[\"|\#|\'|\$].*$/)
	    {
		$sLineorthmorph = build_diacritic_form($sLineorth, $sLinemorph, $checkfile);
		$horthmorph{$key} = $sLineorthmorph;
	    }
	    else
	    {
		$horthmorph{$key} = $sLinemorph;
		$unchangedcounter++;
	    }

	}

    $hashsize = keys %horthmorph;

    undef $db1;
    undef $db2;
    undef $dbout;
    untie (%horthmorph);
    untie (%hmorph);
    untie (%horth);

    print "valid lines of inputfile: $linecounter , unchanged: $unchangedcounter , number of entries in hash: $hashsize\n";
    return ($sorthmorphoutputfile);
}


sub build_diacritic_form
{
    my ($sLineorth, $sLinemorph, $checkfile) = @_;
    my ($sLineorthmorph,
	$morphword,
	$orthword,
	$before,
	$offset,
	$result,
	);

# Here you can find critical cases that should be checked

    $sLinemorph =~ /^(.*?)\\.*$/;
    $morphword = $1;
    $sLineorth =~ /^(.*?)\\.*$/;
    $orthword = $1;
    $sLineorthmorph = $sLinemorph;

    if ($orthword =~ /^(.*?)\$.*$/)  #sz
    {
      if ($morphword =~ /\.*(.)ss.*(.)ss/) # maybe problematic
      {
	  if ($1 eq $2)
	  {
	  open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
	  print AUSGABE "$morphword\n";
	  }
#error is reduced by heuristics: comparison of the two letters before ß is included
	
	  $sLineorthmorph= substitute_multiple_characters($orthword, $sLineorthmorph, 2, "\$", "ss", "\ß"); 
      }
      
      else
      {   
	  $sLineorthmorph =~ s/ss/\ß/g; 
      }
    }
 
    if ($orthword =~ /^(.*?)\#e.*$/)  # accent acute
    {
      if ($morphword =~ /\.*(.)e.*(.)e/) # maybe problematic
      {
	  if ($1 eq $2)
	  {
	  open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
	  print AUSGABE "$morphword\n";
	  }
#error is reduced by heuristics: comparison of the two letters before e is included
	
	  $sLineorthmorph= substitute_multiple_characters($orthword, $sLineorthmorph, 2, "\#e", "e", "\é"); 
      }
      
      else
      {   
	  $sLineorthmorph =~ s/e/\é/g; 
      }
    }
 
  # small caps

    if ($sLineorth =~ /.*\"a.*$/)  #ä
    {
	if ($morphword =~ /\.*ae(.).*ae(.)/)   # maybe problematic
	{
	    if ($1 eq $2)
	    {
		open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
		print AUSGABE "$morphword\n";
	    }
#error is reduced by heuristics: comparison of the two letters before ü is included
	    
	    $sLineorthmorph= substitute_multiple_characters_behind($orthword, $sLineorthmorph, -1, "\"a", "ae", "\ä"); 
	}
	
	else
	{   
	    $sLineorthmorph =~ s/ae/\ä/g; 
	}
	if ($sLineorthmorph =~ /.*[\+\\\(]Ae.*$/) # subcondition, if Ue is within analysis
	{
	    $sLineorthmorph =~ s/Ae/\Ä/g;
	}
    }

    if ($sLineorth =~ /.*\"o.*$/)  #ö
    {
	if ($morphword =~ /\.*oe(.).*oe(.)/)  # maybe problematic
	{
	    if ($1 eq $2)
	    {
		open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
		print AUSGABE "$morphword\n";
	    }
#error is reduced by heuristics: comparison of the two letters before ü is included
	    
	    $sLineorthmorph= substitute_multiple_characters_behind($orthword, $sLineorthmorph, -1, "\"o", "oe", "\ö"); 
	}
	else
	{   
	    $sLineorthmorph =~ s/oe/\ö/g; 
	}
	if ($sLineorthmorph =~ /.*[\+\\\(]Oe.*$/) # subcondition, if Ue is within analysis
	{
	    $sLineorthmorph =~ s/Oe/\Ü/g;
	}
    }  


########


    if ($sLineorth =~ /.*\"u.*$/)  #ü
    {
	if ($morphword =~ /\.*ue(.).*ue(.)/)   # maybe problematic
	{
	    if ($1 eq $2)    
	    {
		open (AUSGABE, ">>$checkfile") || die "Cannot open checkfile! ";
		print AUSGABE "$morphword\n";
	    }
#error is reduced by heuristics: comparison of the two letters before ü is included
	    
	    $sLineorthmorph= substitute_multiple_characters_behind($orthword, $sLineorthmorph, -1, "\"u", "ue", "\ü"); 
	}
	
	else
	{   
	    $sLineorthmorph =~ s/ue/\ü/g; 
	}
	if ($sLineorthmorph =~ /.*[\+\\\(]Ue.*$/) # subcondition, if Ue is within analysis
	{
	    $sLineorthmorph =~ s/Ue/\Ü/g;
	}
    }
    
    #big caps
    if ($sLineorth =~ /.*\"A.*$/)  #Ä
    {
	$sLineorthmorph =~ s/Ae/\Ä/g;
	if ($sLineorthmorph =~ /.*[\+\\\(]ae.*$/) # subcondition, if ae is within analysis
	{
	    $sLineorthmorph = substitute_multiple_characters_behind($orthword, $sLineorthmorph, -1, "\"A", "ae", "\ä"); 
	}
    }
    if ($sLineorth =~ /.*\"O.*$/)  #Ö
    {
	$sLineorthmorph =~ s/Oe/\Ö/g;
	if ($sLineorthmorph =~ /.*[\+\\\(]oe.*$/) # subcondition, if oe is within analysis
	{
	    $sLineorthmorph = substitute_multiple_characters_behind($orthword, $sLineorthmorph, -1, "\"O", "oe", "\ö");;
	}
    }
    if ($sLineorth =~ /.*\"U.*$/)  #Ü
    {
	$sLineorthmorph =~ s/Ue/\Ü/g;
	if ($sLineorthmorph =~ /.*[\+\\\(]ue.*$/) # subcondition, if ue is within analysis
	{
	    $sLineorthmorph = substitute_multiple_characters_behind($orthword, $sLineorthmorph, -1, "\"U", "ue", "\ü"); 
	}
    }
  return ($sLineorthmorph);  
}


sub substitute_multiple_characters_behind {
    my ($orthword, $sLineorthmorph, $nlengthofnext, $orthrepresentation ,$old, $new) =@_;
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
	$sLineorthmorph =~ s/$old${next}/$new${next}/g;

	$result = index($orthword, $orthrepresentation, $offset);
    }
    return ($sLineorthmorph);
}


sub substitute_multiple_characters {
    my ($orthword, $sLineorthmorph, $nlengthofnext, $orthrepresentation ,$old, $new) =@_;
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
	$sLineorthmorph =~ s/${next}$old/${next}$new/g;
	$result = index($orthword, $orthrepresentation, $offset);
    }
    return ($sLineorthmorph);
}

sub change_morphs_in_structures 
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
	);

    print "Changing morphs within morphological analyses.\n";

    $db1 = tie (%horthmorphold, 'MLDBM', "$sorthmorphinputfile", O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find hash file $sorthmorphinputfile";
    Dumper($db1->{DB});
    $db1->{DB}->Filter_Push('utf8');

    $dbout = tie (%horthmorphnew, 'MLDBM', "$sorthmorphoutputfile",  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($dbout->{DB});
    $dbout->{DB}->Filter_Push('utf8');
    $linecounter = 0;
    $changedcounter = 0;

    @keys = natkeysort { $_} keys %horthmorphold;

    foreach $key (@keys)
    {
#	print "$key\n";
	$linecounter++;
	$slineorthmorph = $horthmorphold{$key};
	
        $stransformed = $slineorthmorph;
	
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


   	$horthmorphnew{$key} = $stransformed;
	if ($stransformed ne $slineorthmorph)
	{
	    $changedcounter++;
	}
    }
    $hashsize = keys %horthmorphnew;
    undef $db1;
    undef $dbout;
    untie (%horthmorphold);
    untie (%horthmorphnew);

    print "valid lines of inputfile: $linecounter , changed: $changedcounter , number of entries in hash: $hashsize\n";
    return ($sorthmorphoutputfile);
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
