=pod

=head1 NAME

<GNcompoundswithCELEX> Takes xml-files of GermaNet and extracts trees structures of the compounds.  Many options can be made, e.g. restricting the trees to a certain depth of analysis. Optionally, these analyses can be combined with the analyses of the refurbished CELEX database for German. Also here, many options can be made, e.g. skip conversions or restrict the trees to a certain depth of analysis.

=head1  VERSION

Draft Version

=head1 SYNOPSIS
Synopsis in GNcompoundswithCELEX.help

=head1 REQUIREMENTS

files GMOLoutputneworthography
      GSOLoutputneworthography
inputdirectory with GermaNet xml files
or inputfile (GN xml file)

=head1 USE

Description in GNcompoundswithCELEX.help

=head1 ARGUMENTS

see  GNcompoundswithCELEX.help

=head1 OPTIONS

see  GNcompoundswithCELEX.help

=head1 SUBROUTINES

=head2 output_of_tied_hashs
takes $inputhashfile and $outputtextfile
sorts keys and writes keys and value to the output

=head2 addinfinitivestems
takes $ics: string with immediate constituents and @positions of verbs
adds infinitive stems at the positions
returns $newics

=head2 mycartesian
takes an array
returns the Cartesian product of the subsets of the array

=head2 output_of_tied_hash_witharraysinlines
takes $inputhashfile and $outputtextfile
sorts keys and writes keys and value to the output
the values are arrays, these are sorted and printed
to the output file

=head2 insert_fillerletters
takes $orthform (e.g. Werkstueck, Staedtebau) and $set (reference to array, e.g. [Werk Stueck] [Stadt Bau])
if there is a divergence between the $orthform and joined set
returns $refnew_setstr, a reference to a new array like $set, but with filler letters, e.g. [Stadt e Bau]

=head2 buildanalyses
takes  $inputhashfile, 
some previously created hashfiles,
parameters for the number of analysis levels and levenshtein methods, 
flags for infosintree, pos, parenthesis style, 
flags additional celex analyses and previously created celex hash files
and writes the generated result with morphological analyses to $outputhashfile,
if no analyses can be found of deep_buildanalyses and flagcelex is 1, deep_addcelexsplits is called.
calls deep_buildanalyses, deep_addcelexsplits, mycartesian


=head2 deep_buildanalyses
works recursively, called by buildanalyses, 
takes an array with a word constituent from above, 
parameters for the number of analysis levels and levenshtein methods, 
the current values of these parameters
flags for infosintree and pos
calls deep_addcelexsplits, mycartesian


=head2 deep_addcelexsplits
works recursively, called by buildanalyses and deep_buildanalyses 
takes an array with a word constituent from above, 
parameters for the number of analysis levels and levenshtein methods, 
the current values of these parameters
flags for infosintree and pos
calls deep_addcelexsplits, mycartesian


=head1 DIAGNOSIS

File XY  could not be opened - check for path and name

=head1 INCOMPATABILITIES

Not known

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR(S)

Petra Steiner

=head1 COPYRIGHT

Distribution only by Petra Steiner 

=cut

#!/usr/bin/perl -w 

#example, compounds without foreign words and proper names, add filler letters, use 4 levels, add celex split, no Conversion (Z)

#put the GN files into -d DIRECTORY, e.g. filesGN11
#perl GNcompoundswithCELEX.pl -d filesGN11 -rmpn -rmfw -addfl -n 4 -celex > out2402 2>&1 &

# as above plus add linguistic information (currently just the constructs)
#perl GNcompoundswithCELEX.pl -d filesGN11 -rmpn -rmfw -addfl -n 4 -celex -it > out2402 2>&1 &

# perl GNcompoundswithCELEX.pl -d filesGN11 -rmpn -rmfw -addfl -n 4 -celex -pos -it -ctags -zn 3 -par -levperc 0.5 > out2006 2>&1
# levperc 0.5 yields reasonable results

#use strict "vars";
use warnings;
use DB_File;
#use Fcntl;
use Tie::File;

use MLDBM qw (DB_File FreezeThaw);
use FreezeThaw;

use Data::Dumper qw(Dumper);

use List::Util qw(first none all min max any);
use List::MoreUtils qw(indexes uniq first_index firstidx uniq pairwise);
use String::Diff;
use Text::Levenshtein 0.11 qw(distance);
    
$Data::Dumper::Useqq = 1;

use DBM_Filter;

use I18N::Langinfo qw(langinfo CODESET);
my $codeset = langinfo(CODESET);

print "Codeset: $codeset\n\n";

use Encode qw(decode);

@ARGV = map { decode $codeset, $_ } @ARGV;
print "Args: @ARGV\n";

#no warnings 'utf8';

use open ':utf8';
use utf8;
use open qw(:encoding(UTF-8));

use Getopt::Long;
use Cwd;
use File::Basename;
use locale;

binmode STDIN, ":encoding(UTF-8)";

#binmode STDOUT, ":encoding(UTF-8)";
binmode STDOUT, 'utf8';
binmode STDERR, ":encoding(UTF-8)";

$| = 1;

use XML::LibXML qw(:libxml);
use Sort::Key::Natural qw(natkeysort natsort);

BEGIN { our $start_run = time(); }

my($pathname,
   $base,
   $db,
   $db1,
   $db2,
   $dbpos,
   $dbics,
   $dbicsinfs,
   $dbicsstructs,
   $dblist,
   $dblistinverted,
   $linecounter,
   $sInputFilename,
   $sInputDir,
   $nfile,
   $index,
   $tree,
   $tree1,
   $ics,
   $icpos,
   $lemmapos,
   $morphstatus,
   $icstruct,
   $stem,
   $stemcopy,
   $lengthsubstrorth,
   $lengthsubstrstem,
   $substrorth,
   $substrstem,
   $newlength,
   $sFilename,
   $slistFilename,
   $sOutputFilename,
   $sCompoundFilename,
   $sCELEXfile,
   $niterations,
   $flagcelex,
   $flagzusammenrueckungen,
   $flaginfosintree,
   $flagpos,
   $flagparstyle,
   $flagcelextags,
   $nlevenshtein,
   $levdistance,
   $ziterations,
   $nit,
   $snitstring,
   $removeforeignwords,
   $removepropernames,
   $faddfillerletters,
   $sjustCompoundsFilename,
   $hashfilecompounds,
   $hashfileanalyses,
   $hashfileallcompounds,
   $hashfileallanalyses,
   $outputfileallcompounds,
   $outputfileallanalyses,
   $outputhashcelexanalyses,
   $outputhashcelexallanalyses,
   $hashfilecelexZ,
   $hashfilecelexpos,
   $hashfilecelexics,
   $hashfilecelexicsinfs,
   $hashfilecelexicsstructs,
   $hashfilecelexlist,
   $hashfilecelexlistinverted,
   $hashfilecelexstemallomorphs,
   $hashfilecelexdissimallomorphs,
   $hashfilecompleteinvertedlist,
   %hcelexz,
   %hcelexpos,
   %hcelexics,
   %hcelexicsinfs,
   %hcelexicsstructs,
   %hcelexlist,
   %hcelexlistinverted,
   %hcelexstemallos,
   %hcelexdissimallos,
   %hcelexcompleteinvertedlist,
   @aFileList,
   $outputfilecompounds,
   $outputfileanalyses,
   $doc,
   $doc2,
   $nlexunit,
   $nalllexunit,
   $ncompound,
   $allncompound,
   $ncompcount,
   $lexunit,
   $lexUnitstring,
   $orthform,
   $orthformcopy,
   $orthformstring,
   $form,
   $help,
   $helpfile,
   $textstring,
   $scompounds,
   @acompound,
   $compoundentry,
   @list,
   @sortlist,
   @lista,
   @sortlista,
   $ref_list,
   $ref_lista,
   $ref_index,
   @tagnames,
   @tagsincompound,
   @amodifiers,
   @apos,
   @aheads,
   @amodifiersheads,
   $pos,
   $possyn,
   $possynstring,
   @acartesianresult,
   $part,
   $set,
   $refnew_setstr,  
   @aset,
   $setstring,
   $newsetstring,
   @allsetstrings,
   $nodename,
   @keys,
   $key,
   $value,
   $hashsize,
   $cmd,
   $firstpart,
   $rest,
   $cwd,
   %hcompoundsall,
   %hcompounds,
    );

our (%hcelexlisti, # for inverted index
     %hcelexicsa, # for ics
     %hcelexposa,  # for pos
     %hcelexicstructsa, # for icstructs
     %hzallo, #for conversions with stem allomorphy
     %hzdiss,
    );

## Projection of GermaNet categories to CELEX-style ones.

  my %hGNtoCELEXpos = (
      'nomen' => 'N',
      'Nomen' => 'N',
      'Adjektiv' => 'A',
      'Adverb' => 'B',
      'Präposition' => 'P',
      'Verb' => 'V',
      'verben' => 'V',
      'Artikel' => 'D',
      'Interjektion' => 'I',
      'Pronomen' => 'O',
      'Abkürzung' => 'X',
      'Wortgruppe' => 'n', # n(CELEX): node
      'Konfix' => 'R', # Wurzel but not systematically the same
    );


$helpfile = "GNcompoundswithCELEX.help";

$cwd = `pwd`; # current path
chomp $cwd;
$sInputFilename = "$cwd\/filesGN11\/nomen.Artefakt.xml";

# if not defined by options

$niterations = 0;
$ziterations = 0;
$flagcelex = 0;
$flagzusammenrueckungen = 0;
$flaginfosintree = 0;
$flagpos = 0;
$flagcelextags = 0;
$flagparstyle = 0;
$nlevenshtein = 0;

GetOptions(
    'i=s' => \$sInputFilename,
    'd=s' => \$sInputDir,
    'rmfw' => \$removeforeignwords,
    'rmpn' => \$removepropernames,
    'addfl' => \$faddfillerletters,
    'n=i' => \$niterations, # depth of tree for compounds and derivations
    'zn=i' => \$ziterations, # depth of tree for Zusammenrueckungen (in CELEX)
    'levperc=f' => \$nlevenshtein, # range 0:1
    'celex' => \$flagcelex,
    'zcelex' => \$flagzusammenrueckungen,
    'ctags' => \$flagcelextags,
    'it' => \$flaginfosintree,
    'pos' => \$flagpos,
    'par' => \$flagparstyle,
    'h' =>  \$help,
    );

if ($help)
{
    # print "Helpfile: $helpfile";
    open (HELP, '<', $helpfile) or die "couldn't open $helpfile: $!"; 
    while (<HELP>) 
    {print $_}; 
    close HELP;
    exit;
}

# for call in buildanalyses, in case they are not created
$hashfilecelexlistinverted = "";	
$hashfilecelexicsinfs = "";
$hashfilecelexicsstructs = "";
$hashfilecelexstemallomorphs = ""; 
$hashfilecelexdissimallomorphs = "";
$hashfilecelexpos = "";

### This part creates all data, according to the options

if ($niterations)
{
    $snitstring = $niterations;
}
else
{
    $snitstring = "";
}

## Zusammenrueckungen and stem allomorphy %hcelexstemallos in $hcelexstemallomorphs, control output GMOLzallos


if ($ziterations) # if Zusammenrueckungen, then get CELEX data
{
    $flagzusammenrueckungen = 1;
    $hashfilecelexstemallomorphs = "GMOLzallos_hash";
    if (-e $hashfilecelexstemallomorphs) # just open and close it to check it
    {
	print "\n Loading hash file with CELEX conversions plus stem allomorphy.\n";
	$dbpos = tie (%hcelexstemallos, 'MLDBM', $hashfilecelexstemallomorphs, 
		   O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexstemallomorphs";
	Dumper($dbpos->{DB});
	$dbpos->{DB}->Filter_Push('utf8');
	undef $dbpos;
	untie (%hcelexstemallos); 	
    }
    else # create it
    {
	$sCELEXfile = GMOLoutputneworthography;
	if ( ! -e $sCELEXfile) {die "$sCELEXfile does not exist."};
	open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
	# Das Hashergebnis in eine Datei schreiben
	$db = tie (%hcelexstemallos, 'MLDBM', $hashfilecelexstemallomorphs,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
	Dumper($db->{DB});
	$db->{DB}->Filter_Push('utf8');
	$linecounter = 0;
	print "\n Hash production starts for conversions with stem allomorphy in $sCELEXfile.\n";
	while(<$INPUTC>)
	{
	 #  print "Celex line: $_ \n";
	    chomp $_;
	    if ($_ =~ /^(\d+)\\(.*?)\\\d+\\Z\\(.*?\\){6}Y\\.*$/ )
	    {
		$linecounter++;
		$index = $1;
		$orthform = $2;
		$hcelexstemallos{$index} = $orthform;
	    }
	   else
	   {
	    #   print "Could not process Line $_\n";
	   }
	}
	close $INPUTC;
	$hashsize = keys %hcelexstemallos;
	undef $db;
	untie (%hcelexstemallos);
	
	print "conversions with stem allomorphy in $sCELEXfile: $linecounter , number of entries in hash (types): $hashsize \n";
	# Control output to GMOLzallos
	$sFilename = "GMOLzallos";
	output_of_tied_hashs($hashfilecelexstemallomorphs, $sFilename);
    }
}
else
{
#    $szitstring = 0;
}


## if there is a non-zero levenshtein limit, range 0:1
## %hcelexdissimallos in $hashfilecelexdissimallomorphs, control output GMOLdissimallos


if ($nlevenshtein)
{
    $flagzusammenrueckungen = 1;
    $hashfilecelexdissimallomorphs = "GMOLzdissimallos_hash";

# always create it freshly, because we do not know the last levenshtein distance
    
    $sCELEXfile = GMOLoutputneworthography;
    if ( ! -e $sCELEXfile) {die "$sCELEXfile does not exist."};
    open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
    # Das Hashergebnis in eine Datei schreiben
    $db = tie (%hcelexdissimallos, 'MLDBM', $hashfilecelexdissimallomorphs,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    $linecounter = 0;
    print "\n Hash production starts for stem allomorphy with big levenshtein distance in $sCELEXfile.\n";

    while(<$INPUTC>)
    {
#	print "Celex line: $_ \n";
	chomp $_;
	# check for conversions (indicated by Z)
	if ($_ =~ /^(\d+)\\(.*?)\\\d+\\Z\\(.*?\\){4}(.*?)\\(.*\\?)Y\\.*$/ )
	{
	    $index = $1;
	    $orthform = $2;
	    $stem = $4;
	    # take the orthographical form and the stem, e.g. driften, treiben
	    $orthformcopy = $orthform;
	    $stemcopy = $stem;
	    
	    # make some adjustments to the compared forms
	    # (umlauts, ss, lower capitals)
	    
	    $orthformcopy =~ tr/äöü/aou/;
	    $stemcopy =~ tr/äöü/aou/;
	    
	    $orthformcopy =~ s/ß/ss/;
	    $stemcopy =~ s/ß/ss/;
	    $orthformcopy = lc $orthformcopy;
	    $stemcopy = lc $stemcopy;
	   # print "Copies after adjusting: $orthformcopy, $stemcopy\n";
	    
	    $lengthsubstrorth = length($orthformcopy);
	    $lengthsubstrstem = length($stemcopy);
	   
	    # find the minimum of both lengths
	    $newlength = min($lengthsubstrorth, $lengthsubstrstem);
	    # cut the two forms to this minimum   
	    $substrorth = substr ($orthformcopy, 0, $newlength);
	    $substrstem = substr ($stemcopy, 0, $newlength);
	    # calculate the levenshtein distance
	    $levdistance = distance($substrorth, $substrstem);

	    # compare relation l. distance / length of compared forms
	    if (($levdistance / $newlength) > $nlevenshtein)
	     {
		 ++$linecounter;
		print "Large Levenshtein distance $levdistance between $orthform and $stem\n";
		 # exceptions
		 
		 if (none {$_ eq $orthform} qw (Angebot Sicht))  # exception of exceptions
		 {
		     # add these forms to dissimilar forms
		     $hcelexdissimallos{$index} = $orthform . "\\" . $stem;
		 }
	     }
	}
	else
	{
	    #print "Could not process Line $_\n";
	}
    }
    close $INPUTC;
    $hashsize = keys %hcelexdissimallos;
    undef $db;
    untie (%hcelexdissimallos);
    
    print "stem allomorphy with levenshtein-share distance more or equal than $nlevenshtein in  $sCELEXfile: $linecounter , number of entries without exceptions in hash (types): $hashsize \n";
    # Control output to GMOLdissimallos
    $sFilename = "GMOLzdissimallos";
    output_of_tied_hashs($hashfilecelexdissimallomorphs, $sFilename);
}

##### end of getting dissimilar conversions

## get Zusammenrueckungen (conversions)
## %hcelexz in GMOLz_hash, control output GMOLz


if ($flagzusammenrueckungen)
{
    $flagcelex = 1; # for next condition
    # prepare conversions/Zusammenrueckungen
    $hashfilecelexZ = "GMOLz_hash";
    if (-e $hashfilecelexZ) # just open and close it to check it
    {
	print "\n Loading hash file with CELEX conversions/Zusammenrückungen.\n";
	$dbpos = tie (%hcelexz, 'MLDBM', $hashfilecelexZ, 
		   O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $hashfilecelexZ";
	Dumper($dbpos->{DB});
	$dbpos->{DB}->Filter_Push('utf8');
	undef $dbpos;
	untie (%hcelexz); 	
    }
    else # create it
    {
	$sCELEXfile = GMOLoutputneworthography;
	if ( ! -e $sCELEXfile) {die "$sCELEXfile does not exist."};
	
	open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
	$db = tie (%hcelexz, 'MLDBM', $hashfilecelexZ,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
	Dumper($db->{DB});
	$db->{DB}->Filter_Push('utf8');
	
	$linecounter = 0;
	print "\n Hash production starts for conversions in $sCELEXfile.\n";
	while(<$INPUTC>)
	{
	  #  print "Celex line: $_ \n";
	    chomp $_;
	    if ($_ =~ /^(\d+)\\(.*)\\(\d+)\\Z\\(.*?\\){4}(.*?)\\(.*?)\\(.*?\\){3}(.*?)\\.*$/ )
	    {
		 $linecounter++;
		 $index = $1;
		 $stem = $5;
		 $icpos = $6;
		 $tree = $8;
		 $tree =~ /^\(.*\)\[(.*)\]$/;
		 #print "Tree: $tree\n";
		 $lemmapos = $1;
		 # if conversion from verb, add infinitive suffix to stem
		 if ($icpos eq "V")
		 {
		     $stem .= "en"; # then create the allomorphs
		     $stem =~ s/(eie[lr])en$/$1n/;#feiern
		     $stem =~ s/([^i]e[lr])en$/$1n/;
		      $stem =~ s/(que[lr])n$/$1en/; # queren
		     $stem =~ s/^tuen$/tun/;
		 }
		 #print "\n $stem \n";
		 
		 # if V with a conversion from a non-verb  - case ((Aal)[N])[V]

		 if (($lemmapos eq "V") && ($icpos ne "V"))
		 {
		     $stem .= "|en"; # for the sake of consistency add morph
		    # print "$stem\n"; # then create the allomorphs
		     $stem =~ s/(eie[lr])\|en$/$1|n/; #feiern
		   #  print "$stem\n";
		     $stem =~ s/([^i]e[lr])\|en$/$1|n/;
		     $stem =~ s/(e)\|en$/$1|n/;
		     $stem =~ s/gen\|en$/gen/;
		     $stem =~ s/chen\|en$/chen/;
		     $stem =~ s/^tu\|en$/tun/;
		    $stem =~ s/^er\|en$/er|zen/;
		     $stem =~ s/^du\|en$/du|zen/;
		     $stem =~ s/^Sie\|n$/Sie|zen/;
		     $stem =~ s/(que[lr])\|n$/$1|en/;#queren
		 }
		 if ($icpos ne "F")
		 {
		     #print "Conversion entry: $stem\n";
		     $hcelexz{$index} = $stem;
		 }
		 else
		 {
		   #  print "No valid conversion: $stem\n";
		 }
	    }	    
	    else
	    {
		# print "Could not process Line $_\n";
	    }
	}
	close $INPUTC;
	$hashsize = keys %hcelexz;
	undef $db;
	untie (%hcelexz);
	
	print "valid conversions in $sCELEXfile: $linecounter , number of entries in hash (types): $hashsize \n";
		# Control output to GMOLz
	$sFilename = "GMOLz";
	output_of_tied_hashs($hashfilecelexZ, $sFilename);
    }
}

#### end of Zusammenrueckungen

### Celex processing
## 1. get pos, %hcelexpos in GMOLpos_hash, control output in GMOLpos
## 2. get ICs, %hcelexics in GMOLics_hash, control output in GMOLics,
## 3. get IC structures, %hcelexicsstructs in GMOLicstructs_hash, 
##    control output in GMOLicstructs
## 4. build infinitive forms for the IC structures, 
##    %hcelexicsinfs in GMOLicsinfs_hash, use
##    %hcelexics and %hcelexicsstructs, no control output
##    if Zusammenrueckungen, use %hcelexz and add the entries, no control output

## 5. build inverted list %hcelexlistinverted  in GMOLlistinverted_hash
##    control output to GMOLlistinverted
## 5a for this use or build index-word-list: %hcelexlist in GMOLlist_hash, 
##    control output in GMOLlist
## 5b for this use or build %hcelexcompleteinvertedlist in GMOLcompleteinverted_hash
##    control output in GMOLcompleteinvertedlist
##    use %hcelexics
##    if Zusammenrueckungen use %hcelexz
		
if ($flagcelex) # prepare information for the derivational part
{
    # first the PoS
    $hashfilecelexpos = "GMOLpos_hash";
    if (-e $hashfilecelexpos)
    {
	print "\n Loading hash file with CELEX PoS.\n";
	$dbpos = tie (%hcelexpos, 'MLDBM', $hashfilecelexpos, 
		   O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexpos";
	Dumper($dbpos->{DB});
	$dbpos->{DB}->Filter_Push('utf8');
	undef $dbpos;
	untie (%hcelexpos); 
    }
        else
	# create it
    {
	$sCELEXfile = GSOLoutputneworthography; # German syntax
	if ( ! -e $sCELEXfile) {die "$sCELEXfile does not exist."};
	
	open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
	
	$dbpos = tie (%hcelexpos, 'MLDBM', $hashfilecelexpos, 
		   O_TRUNC|O_CREAT, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexpos";
	Dumper($dbpos->{DB});
	$dbpos->{DB}->Filter_Push('utf8');
	$linecounter = 0;
	print "\n Hash production starts for PoS in $sCELEXfile.\n";
	while(<$INPUTC>)
	{
	  #  print "Celex line: $_ \n";
	    chomp $_;
	    if ($_ =~ /^(\d+)\\(.*?)\\(\d+)\\(\d+)\\.*\\.*$/ )
	    {
		$linecounter++;
		$index = $1;
		$lemmapos = $4;
		$lemmapos =~ s/10/I/; # replace number codes by letters as in the IC structures
		$lemmapos =~ tr/123456789/NAQVDOBPC/;
		$hcelexpos{$index} = $lemmapos;		
	    }
	     else
	    {
		# print "Could not process Line $_ for PoS entry.\n";
	    }
	}
	close $INPUTC;
	$hashsize = keys %hcelexpos;
	undef $dbpos;
	untie (%hcelexpos);
	
	print "valid PoS in $sCELEXfile: $linecounter , number of entries in hash (types): $hashsize \n";
	
	# Control output to GMOLpos
	$sFilename = "GMOLpos";
	output_of_tied_hashs($hashfilecelexpos, $sFilename);
    }
    
    #then the ICs
    $hashfilecelexics = "GMOLics_hash";

    if (-e $hashfilecelexics)
    {
	print "\n Loading hash file with CELEX IcS.\n";
	$dbics = tie (%hcelexics, 'MLDBM', $hashfilecelexics, 
		   O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $hashfilecelexics";
	Dumper($dbics->{DB});
	$dbics->{DB}->Filter_Push('utf8');
	undef $dbics;
	untie (%hcelexics); 
    }

    else
	# create it
    {
	$sCELEXfile = "GMOLoutputneworthography";
	if ( ! -e $sCELEXfile) {die "$sCELEXfile does not exist."};
	open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
	# Das Hashergebnis in eine Datei schreiben

	$dbics = tie (%hcelexics, 'MLDBM', $hashfilecelexics, 
		   O_TRUNC|O_CREAT, 0666, $DB_BTREE);
	Dumper($dbics->{DB});
	$dbics->{DB}->Filter_Push('utf8');
	$linecounter = 0;
	print "\n Hash production starts for PoS of complex ICs in $sCELEXfile.\n";
	
	while(<$INPUTC>)
	{
	   # print "Celex line: $_ \n";
	    chomp $_;
	    if ($_ =~ /^(\d+)\\(.*?)\\(\d+)\\C\\(.*?\\){4}(.*?)\\.*$/)
	    {
		$linecounter++;
		$index = $1;
		$ics = $5;
		$ics =~ s/\+/\|/g;	# substitute + by |
		$hcelexics{$index} = $ics;		
	    }
	     else
	    {
		# print "Could not process Line $_ for IC entry.\n";
	    }
	}
	close $INPUTC;
	$hashsize = keys %hcelexics;
	undef $dbics;
	untie (%hcelexics);
	
	print "valid ICs in $sCELEXfile: $linecounter , number of entries in hash (types): $hashsize \n";
	
	# Control output to GMOLics
	$sFilename = "GMOLics";
	output_of_tied_hashs($hashfilecelexics, $sFilename);
    }


    ## and the IC structures
    
    $hashfilecelexicsstructs = "GMOLicstructs_hash";
    
 if (-e $hashfilecelexicsstructs)
    {
	print "\n Loading hash file with CELEX Icstructs.\n";
	$dbicsstructs = tie (%hcelexicsstructs, 'MLDBM', $hashfilecelexicsstructs, 
		   O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexicsstructs";
	Dumper($dbicsstructs->{DB});
	$dbicsstructs->{DB}->Filter_Push('utf8');
	undef $dbicsstructs;
	untie (%hcelexicsstructs); 
    }

    else
	# create it

    {
	$sCELEXfile = "GMOLoutputneworthography";
	if ( ! -e $sCELEXfile) {die "$sCELEXfile does not exist."};

	open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
	$dbicsstructs = tie (%hcelexicsstructs, 'MLDBM', $hashfilecelexicsstructs, 
			     O_TRUNC|O_CREAT, 0666, $DB_BTREE);
	Dumper($dbicsstructs->{DB});
	$dbicsstructs->{DB}->Filter_Push('utf8');
	$linecounter = 0;
	print "\n Hash production starts for index-ICstruct-list in $sCELEXfile.\n";
	while(<$INPUTC>)
	{
	    #print "Celex line: $_ \n";
	    chomp $_;
	    if ($_ =~ /^(\d+)\\(.*?)\\(\d+)\\(.)\\(.*?\\){5}(.*?)\\(.*?\\){3}(.*?)\\.*$/ )
	    {
		$linecounter++;
		$index = $1;
		$morphstatus = $4;
		$orthform = $2;
		$icstruct = $6;
		#print "ICstruct: $icstruct\n";
		$tree =$8;
		#print "Tree: $tree\n";
		$tree =~ /^\(.*\)\[(.*)\]$/;
		$lemmapos = $1;
	#	print "Orthform: $orthform\n";
		if ($flagpos && $flagzusammenrueckungen && ($morphstatus eq "Z") && ($lemmapos eq "V") && ($icstruct ne "V") && (none {$_ eq $orthform} qw (zeichnen eignen entgegnen tun)))
		{ #add suffix
		 #   print "Z: $orthform\n";
		    $icstruct .= "x"; #add category for suffix
		}
		
		# print "Orthform: $orthform\n";
		$hcelexicsstructs{$index} = $icstruct;
	    }
	    else
	    {
		# print "Could not process for GMOLicstructs_hash: Line $_\n";
	    }
	}
	close $INPUTC;
	$hashsize = keys %hcelexicsstructs;
	undef $dbicsstructs;
	untie (%hcelexicsstructs);
	print "valid ICstructs entries in $sCELEXfile: $linecounter, number of entries in hash (types): $hashsize \n";
	#  Control output to GMOLicstructs
	$slistFilename = "GMOLicstructs";
	output_of_tied_hashs($hashfilecelexicsstructs, $slistFilename);   close $INPUTC;
    }	
    ## the verbs in the ics have to be changed to the infinitive form
    
    #open new hash for output

    $hashfilecelexicsinfs = "GMOLicsinfs_hash";
    
    $dbicsinfs = tie (%hcelexicsinfs, 'MLDBM', $hashfilecelexicsinfs, 
			    O_TRUNC|O_CREAT, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexics";
    Dumper($dbicsinfs->{DB});
    $dbicsinfs->{DB}->Filter_Push('utf8');
 
    # read the ics
    
    $dbics = tie (%hcelexics, 'MLDBM', $hashfilecelexics, 
		  O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexics";
    Dumper($dbics->{DB});
	$dbics->{DB}->Filter_Push('utf8');
    
    #read the icsstructs
    	$dbicsstructs = tie (%hcelexicsstructs, 'MLDBM', $hashfilecelexicsstructs, 
		   O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexicsstructs";
	Dumper($dbicsstructs->{DB});
	$dbicsstructs->{DB}->Filter_Push('utf8');
    
	while (($key, $value) = each %hcelexics) 
	{
	  #  print "$key, $value\n";
	    #only if icsstruct exists and there is a verb
	    if ((exists $hcelexicsstructs{$key}) && (my @pos = indexes { $_ eq "V"}  split //, $hcelexicsstructs{$key}) )
	    {
		#print "Verb: $value\n";
		my $newvalue = addinfinitivestems($value, @pos);
		# print "New verb: $newvalue\n";
		$hcelexicsinfs{$key}=$newvalue;
	    }
	    else # do nothing, add the entry
	    {
		$hcelexicsinfs{$key}=$value;
	    }
	}
    
    undef $dbicsstructs;
    untie (%hcelexicsstructs);
    undef $dbics;
    untie (%hcelexics);

####    
# in case the Zusammenrueckungen/conversions should be added too
    if ($flagzusammenrueckungen)
    {
	$dbics = tie (%hcelexz, 'MLDBM', $hashfilecelexZ, 
		  O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexics";
	Dumper($dbics->{DB});
	$dbics->{DB}->Filter_Push('utf8');
	while (($key, $value) = each %hcelexz)
	{
	    $hcelexicsinfs{$key}=$value;
	}	
    }
    undef $dbics;
    untie (%hcelexz);

    undef $dbicsinfs;
    untie (%hcelexicsinfs); 
   
    $hashfilecelexlistinverted = "GMOLlistinverted_hash";

#always create it new
     
    $hashfilecelexlist = "GMOLlist_hash"; # helpfile

    if (-e $hashfilecelexlist) # just open and close it to check it
    {
	print "\n Loading hash file with CELEX list.\n";
	$dblist = tie (%hcelexlist, 'MLDBM', $hashfilecelexlist, 
		   O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $hashfilecelexlist";
	Dumper($dblist->{DB});
	$dblist->{DB}->Filter_Push('utf8');
	undef $dblist;
	untie (%hcelexlist); 	
    }
    else # create it
    {
	$sCELEXfile = GMOLoutputneworthography;
	if ( ! -e $sCELEXfile) {die "$sCELEXfile does not exist."};
	open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
	# Das Hashergebnis in eine Datei schreiben
	$dblist = tie (%hcelexlist, 'MLDBM', $hashfilecelexlist,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
	Dumper($dblist->{DB});
	$dblist->{DB}->Filter_Push('utf8');
	$linecounter = 0;
	print "\n Hash production starts for index-word-list in $sCELEXfile.\n";
	while(<$INPUTC>)
	{
	  #  print "Celex line: $_ \n";
	    chomp $_;
	     if ($_ =~ /^(\d+)\\(.*?)\\(\d+)\\.*\\(.*?\\){4}(.*?)\\(.*?)\\(.*?\\){3}(.*?)\\.*$/ )
	     {
		 $linecounter++;
		 $index = $1;
		 $orthform = $2;
		# print "Orthform: $orthform\n";
		 $hcelexlist{$index} = $orthform;
	     }
	     else
	     {
		#  print "Could not process for GMOLlist: Line $_\n";
	     }
	}
	close $INPUTC;
	$hashsize = keys %hcelexlist;
	undef $dblist;
	untie (%hcelexlist);
	print "valid lines in $sCELEXfile: $linecounter , number of entries in hash (types): $hashsize \n";
    }
#  Control output to GMOLlist
    $slistFilename = "GMOLlist";
    output_of_tied_hashs($hashfilecelexlist, $slistFilename);   

    $hashfilecompleteinvertedlist = "GMOLcompleteinverted_hash";
    
    if (-e $hashfilecompleteinvertedlist) # just open and close it to check it
    {
	print "\n Loading hash file with CELEX invertedlist.\n";
	$dblist = tie (%hcelexcompleteinvertedlist, 'MLDBM', $hashfilecelexlist, 
		   O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $hashfilecompleteinvertedlist";
	Dumper($dblist->{DB});
	$dblist->{DB}->Filter_Push('utf8');
	undef $dblist;
	untie (%hcelexcompleteinvertedlist); 	
    }
    else # create it
    {
	$sCELEXfile = GMOLoutputneworthography;
	if ( ! -e $sCELEXfile) {die "$sCELEXfile does not exist."};
	open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
	# Das Hashergebnis in eine Datei schreiben
	$dblist = tie (%hcelexcompleteinvertedlist, 'MLDBM', $hashfilecompleteinvertedlist,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
	Dumper($dblist->{DB});
	$dblist->{DB}->Filter_Push('utf8');
	$linecounter = 0;
	print "\n Hash production starts for inverted index-word-list in $sCELEXfile.\n";
	while(<$INPUTC>)
	{
	   #  print "Celex line: $_ \n";
	    chomp $_;
	    if ($_ =~ /^(\d+)\\(.*?)\\(\d+)\\.*\\(.*?\\){4}(.*?)\\(.*?)\\(.*?\\){3}(.*?)\\.*$/ )
	     {
		 $linecounter++;
		 $index = $1;
		 $orthform = $2;
		 # print "Orthform: $orthform\n";
		 $ref_list = [];
		 if (exists $hcelexcompleteinvertedlist{$orthform})
		 {
		     $ref_list = $hcelexcompleteinvertedlist{$orthform}; 
		     @list = @$ref_list;
		     push(@list, $index);
		     $ref_list = \@list;
		 }
		 else
		 {
		     push(@{$ref_list}, $index); 
		 }
		 $hcelexcompleteinvertedlist{$orthform}=$ref_list;
	     }
	    else
	    {
		# print "Could not process for GMOLcompleteinvertedlist_hash Line $_\n";
	    }
	}
	close $INPUTC;
	$hashsize = keys %hcelexcompleteinvertedlist;
	undef $dblist;
	untie (%hcelexcompleteinvertedlist);
	print "valid lines in $sCELEXfile: $linecounter , number of entries in hash (types): $hashsize \n";
    
    #  Control output to GMOLcompleteinvertedlist
    
    $slistFilename = "GMOLcompleteinvertedlist";
    output_of_tied_hash_witharraysinlines($hashfilecompleteinvertedlist, $slistFilename);
    }
	
    if ( ! -e $slistFilename) {die "$slistFilename does not exist."};
    
    # now tie again for reading    
    $dblist = tie (%hcelexlist, 'MLDBM', $hashfilecelexlist, 
		   O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexlist";
    Dumper($dblist->{DB});
    $dblist->{DB}->Filter_Push('utf8');
    
    # and read the ics

    $dbics = tie (%hcelexics, 'MLDBM', $hashfilecelexics, 
		  O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexics";
    Dumper($dbics->{DB});
    $dbics->{DB}->Filter_Push('utf8');
    
    $dblistinverted = tie (%hcelexlistinverted, 'MLDBM', $hashfilecelexlistinverted,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($dblistinverted->{DB});
    $dblistinverted->{DB}->Filter_Push('utf8');

    %hcelexlist = ();
    
    while (($key, $value) = each %hcelexlist) 
    {
	#  print "$key, $value\n";
	$ref_list = [];
	#only if ics exist
	if (exists $hcelexics{$key})
	{
	    if (exists $hcelexlistinverted{$value}) # check if there is already an entry
	    {
		$ref_list = $hcelexlistinverted{$value}; 
		@list = @$ref_list;
		push(@list, $key);
		$ref_list = \@list;
	    }
	    else
	    {
		push(@{$ref_list}, $key); 
	    }
	    $hcelexlistinverted{$value}=$ref_list;
	}
    }
    
    $hashsize = keys %hcelexlistinverted;
    print "number of inverted complex IC entries in hash: $hashsize \n";
    undef $dbics;
    untie (%hcelexics);	
    
    # if Zusammenrückungen/conversions
    if ($flagzusammenrueckungen) # add them too
    {
	$dbics = tie (%hcelexz, 'MLDBM', $hashfilecelexZ, 
		  O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexics";
	Dumper($dbics->{DB});
	$dbics->{DB}->Filter_Push('utf8');
	while (($key, $value) = each %hcelexlist) 
	{
	#  print "$key, $value\n";
	    $ref_list = [];
	#only if ics exist
	    if (exists $hcelexz{$key})
	    {
		# check if entry already exists

		if (exists $hcelexlistinverted{$value}) # check if there is already an entry
		{
		    $ref_list = $hcelexlistinverted{$value}; 
		    @list = @$ref_list;
		    push(@list, $key);
		    $ref_list = \@list;
		}
		else
		{
		    push(@{$ref_list}, $key); 
		}
		$hcelexlistinverted{$value}=$ref_list;
	    }
	}
	$hashsize = keys %hcelexlistinverted;
	print "number of entries in hash with conversions: $hashsize \n";
    }
    undef $dbics;
    untie (%hcelexz);
    undef $dblist;
    undef $dblistinverted;
    untie (%hcelexlist);
    untie (%hcelexlistinverted);	
    # Control output to GMOLlistinverted
    $sFilename = "GMOLlistinverted";
    output_of_tied_hash_witharraysinlines($hashfilecelexlistinverted, $sFilename);
}


if ($sInputDir) 
{
    chdir $sInputDir or die "chdir $sInputDir: $!";
    @aFileList = glob ("*.xml");
    $pathname = dirname($aFileList[0]);
    $base = basename($aFileList[0]);
 
    $hashfileallcompounds = "$pathname\/Allin$sInputDir\_compounds\_hash";
    $outputfileallcompounds =  "$pathname\/Allin$sInputDir\_compounds.out";
    $hashfileallanalyses = "$pathname\/Allin$sInputDir\_analyses$snitstring\_hash";
    $outputfileallanalyses =  "$pathname\/Allin$sInputDir\_analyses$snitstring.out";
}

else # just one file
{
    push(@aFileList, $sInputFilename);
    $pathname = dirname($sInputFilename);
    $base = basename($sInputFilename);

    $hashfileallcompounds = "$pathname\/$base\_compounds\_hash";
    $outputfileallcompounds =  "$pathname\/$base\_compounds.out";
    $hashfileallanalyses = "$pathname\/$base\_analyses$snitstring\_hash";
    $outputfileallanalyses =  "$pathname\/$base\_analyses$snitstring.out";
}

$nfile = 0;

# the hash file with all compounds of all files

print "hashfileallcompounds: $hashfileallcompounds\n";

$db1 = tie (%hcompoundsall, 'MLDBM', $hashfileallcompounds,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
Dumper($db1->{DB});
$db1->{DB}->Filter_Push('utf8');

%hcompoundsall = ();


# in case of flagcelextags open the file with all pos

if ($flagcelex)
{
    $hashfilecelexpos = "$cwd\/$hashfilecelexpos";
    $hashfilecompleteinvertedlist = "$cwd\/$hashfilecompleteinvertedlist";
}

if ($flagcelextags && (-e $hashfilecelexpos) && (-e $hashfilecompleteinvertedlist))
{
    # print "Flagcelextags: $hashfilecelexpos\n";
    
    $dbpos = tie (%hcelexpos, 'MLDBM', $hashfilecelexpos, 
		  O_RDONLY, 0666, $DB_BTREE) ||  die "Could not find file $hashfilecelexpos";
    Dumper($dbpos->{DB});
    $dbpos->{DB}->Filter_Push('utf8');
    #$hashsize = keys %hcelexpos;
    # print "number of entries in hash (types): $hashsize \n";

    # and open the complete inverted index too

    $dblist = tie (%hcelexcompleteinvertedlist, 'MLDBM', $hashfilecompleteinvertedlist, 
		   O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $hashfilecelexlist";
    Dumper($dblist->{DB});
    $dblist->{DB}->Filter_Push('utf8');
    $hashsize = keys %hcelexpos;
    print "number of entries in hash (types) in inverted CELEX list: $hashsize \n";
}

### After the lexical data has been collected, the compounds are extracted from GN

    $allnlexunit = 0;
    $allncompound = 0;

foreach $sFilename (@aFileList)
{
    $nfile++;
    $base = basename($sFilename);

    $sCompoundFilename = "$pathname\/$base\.compounds";
    $sjustCompoundsFilename = "$pathname\/$base\.compforms";
    $outputfilecompounds =  "$pathname\/$base\_compounds.out";
    $hashfilecompounds = "$pathname\/$base\_compounds\_hash";
 
    open(SOUTPUT, '>', $sCompoundFilename) or die;
    open(SOUTPUT2, '>', $sjustCompoundsFilename) or die;

    print "hashfilecompounds: $hashfilecompounds\n";

    $db2 = tie (%hcompounds, 'MLDBM', $hashfilecompounds,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($db2->{DB});
    $db2->{DB}->Filter_Push('utf8');

    %hcompounds = ();

    my $parser = XML::LibXML->new;

    print "Parsing of the XML file $sFilename starts.\n";

    $doc = $parser->parse_file($sFilename);
    print "Parsing finished.\n";
    
#    print '$doc is a ', ref($doc);
#    print '$doc->nodeName is: ', $doc->nodeName;
    
#    print 'XML Version is: ', $doc->version;
#    print ' Document encoding is: ', $doc->encoding;
#    my $is_or_not = $doc->standalone ? 'is' : 'is not';
#    print " Document $is_or_not standalone\n\n";
    
    my $synsets = $doc->documentElement;
 #   print ' $synsets is a ', ref($synsets);
 #   print ' $synsets->nodeName is: ', $synsets->nodeName;

    my $XPATH_EXPRESSION = 'synsets/synset';

    my @synsets = $doc->findnodes($XPATH_EXPRESSION);
    
    print "Number of synsets: $#synsets\n";

    $nlexunit = 0;
    $ncompound = 0;
    
    $lexUnitstring = 'synsets/synset/lexUnit';
    $orthformstring = 'orthForm';
    $possynstring = './parent::synset/@category';

    print "Processing the file and finding all compounds ...\n";

    for $lexunit ($doc->findnodes($lexUnitstring))
    {
	$nlexunit++;
	@acompound = $lexunit->findnodes('compound');
	$scompounds = join (' ' , @acompound);    
	$possyn = $lexunit->findnodes($possynstring);
	 
	if ($flagcelextags) { $possyn = ($hGNtoCELEXpos{$possyn} || $possyn) ; }

	# print "Pos of synset: $possyn\n";
	
	if (@acompound) # if compound
	{
	    $ncompound++;
	    $orthform = $lexunit->findvalue($orthformstring);
	   # print "Orthform of lexunit No. $nlexunit : $orthform\n"; 
	    print SOUTPUT "$orthform ";
	    print SOUTPUT2 "$orthform\n";

	    $ref_list = []; # reference to empty array
	    $ref_lista = [];
	    @list = ();
	    @lista = ();

	    for $compoundentry (@acompound)
	    {
		@tagsincompound = $compoundentry->findnodes(".//*");
		@tagnames = map {$_->nodeName()} @tagsincompound;

		# in case of flags first check if there are exceptions and leave if so

		if ($removepropernames && $compoundentry->findnodes(".//*[\@property=\'Eigenname\']") )
		{
		#	print "Eigenname: Orthform of lexunit No. $nlexunit : $orthform\n";
		    next;
		}
		
		if ($removeforeignwords && $compoundentry->findnodes(".//*[\@property=\'Fremdwort\']") )
		{
		#	print "Fremdwort: Orthform of lexunit No. $nlexunit : $orthform\n";
		    next;
		}

		# exclude compounds with empty entries

		if ($compoundentry->findnodes(".//*[not(text())]") )
		{
		    print "empty entry: $orthform not valid\n";
		    next;
		}
		
		if (@tagnames) 
		{
#		    print "Tags in compound: @tagnames\n";
		    @amodifiers = ();
		    @aheads = ();
		    for $part (@tagsincompound)
		    {
			$nodename = $part->nodeName;
			$form = $part->to_literal;
			if ($nodename eq "modifier")
			{
			    # PoS or other e.g. Wortgruppe
			    $pos = ($part->findnodes(".//\@category") or $part->findnodes(".//\@property")); 
			    if ($pos)
			    {
				print "Pos of $form is $pos\n";
				# exceptions: Affixoid, opaquesMorphem
				if (none {$_ eq $pos} qw (Affixoid opaquesMorphem)) 
				{
				    if ($flagcelextags) { $pos = ($hGNtoCELEXpos{$pos} || $pos) ; }		
				    push(@apos, $pos);
				    push (@amodifiers, $form);
				    # put part in list of modifiers
				}
				else
				{
				    print "Non-accepted or erraneous compound entry: $orthform\n";
				}
			    }
				    
			    elsif ($flagcelextags && (exists $hcelexcompleteinvertedlist{$form}))  # if no pos was found in GN, look it up in Celex
			    {
				print "Look-up of PoS in CELEX because of missing entry in GN for $orthform.\n";
				$ref_index = $hcelexcompleteinvertedlist{$form};
				$index = @$ref_index[0]; # just take the first entry
				print "index: $index\n";
				$pos = $hcelexpos{$index};
				print "pos: $pos\n";
				push(@apos, $pos);
				push (@amodifiers, $form);
				# put part in list of modifiers
			    }
			    
			    else
			    {
				print "no pos or other category for a modifier of $orthform\n";
			    }
			}
			elsif ($nodename eq "head")
			{
			    # put part in list of heads
			    push (@aheads, $form);
			}
		    }
		   # print "Modifiers: @amodifiers\n";
		   # print "Heads: @aheads\n";
		    @amodifiersheads[0] = \@amodifiers;
		    @amodifiersheads[1] = \@aheads;
		   # print "Modifierheads: ";
		   # print Dumper (@amodifiersheads);
		    @acartesianresult = mycartesian (@amodifiersheads);
		   
		    if (! @acartesianresult)
		    {
			print "Empty Cartesian set for $orthform.\n";
			next;
		    }
		    
		    # print Dumper (\@acartesianresult);
		    @allsetstrings = ();
		  		  
		    for $set (@acartesianresult)
		    {
			if ($faddfillerletters) 
			{
			   # print "Set for addfillerletters: @$set\n";
			    $refnew_setstr = insert_fillerletters ($orthform, $set);
			    $setstring = join('|', @$refnew_setstr);
			   # print "Orthform: $orthform - New set: @$refnew_setstr\n";
			}
			else
			{
			    $setstring = join ('|', @$set);
			    # print "Set: $setstring\n";
			}
			if ($flagpos)
			{
			    $pos = shift(@apos);
			    #  print "POS $pos\n";
			    # add pos to the first element
			    $setstring =~ /^(.*?)\|(.*)$/;
			    # add category from synset to the last element
			    $newsetstring = "$1\_$pos\|$2\_$possyn";
			    # if longer than two elements add x for the fuge/filler letter
			    if ($newsetstring =~ /^(.*?)\|(.*)\|(.*?)$/)
			    {
				$newsetstring = "$1\|$2\_x\|$3";
			    }
			    print "New: $newsetstring\n";
			    $setstring = $newsetstring;
			}
			
			print SOUTPUT "$setstring ";
			push (@allsetstrings, $setstring);
		    }
		    print SOUTPUT "\n";
		    
		    # put in hashes, first for file
		 
		    if (exists $hcompounds{$orthform})
		    {
			$ref_list = $hcompounds{$orthform}; 
			@list = @$ref_list;
			# print "Already there $line @list, new: $ntext\n";
			push(@list, @allsetstrings);
			@sortlist = uniq (sort @list);
			$ref_list = \@sortlist;
		    }
		    else
		    {
			push(@{$ref_list}, @allsetstrings); 
		    } 
		    
		    $hcompounds{$orthform} = $ref_list;

		    # then for all files

		    if (exists $hcompoundsall{$orthform})
		    {
			$ref_lista = $hcompoundsall{$orthform}; 
			@lista = @$ref_lista;
			#  print "Already there $line @list, new: $ntext\n";
			push(@lista, @allsetstrings);
			@sortlista = uniq (sort @lista);
			$ref_lista = \@sortlista;
		    }
		    else
		    {
			push(@{$ref_lista}, @allsetstrings); 
		    } 
		    $hcompoundsall{$orthform} = $ref_lista;
		}
	    }
	}    
    }

    close(SOUTPUT);
    close(SOUTPUT2);

    $ncompcount = keys %hcompounds;

	
    undef $db2;
    untie (%hcompounds);
 
    print "$nfile Hash for $sFilename finished. No of lexUnits: $nlexunit. No of compounds: $ncompound. No of valid compound entries in hash: $ncompcount. \n";
    $allnlexunit = $allnlexunit + $nlexunit;
    $allncompound = $allncompound + $ncompound;
    
    print "Output of compounds to file $outputfilecompounds\n";
    output_of_tied_hash_witharraysinlines($hashfilecompounds, $outputfilecompounds);
}


if ($flagcelextags && -e $hashfilecelexpos)
{
    undef $dbpos;
    untie (%hcelexpos);
    undef $dblist;
    untie (%hcelexcompleteinvertedlist); 	
}
$ncompcount = keys %hcompoundsall;

 print "Hash for all entries finished. No of lexUnits: $allnlexunit. No of compounds: $allncompound. No of compound entries in hash: $ncompcount. \n";
undef $db1;
untie (%hcompoundsall);
 
output_of_tied_hash_witharraysinlines($hashfileallcompounds, $outputfileallcompounds);

print "Output of all compounds: $outputfileallcompounds \n";

print "Start to build deep analyses for compounds for each file separately, followed by output. \n";

# to make sure to find it 
print "old dir: $cwd\n";

if ($flagzusammenrueckungen)
{    
    $hashfilecelexlistinverted =  $cwd . "\/". $hashfilecelexlistinverted;
}

if ($flagcelex)
{
    $hashfilecelexics = $cwd . "\/" . $hashfilecelexics;
    $hashfilecelexicsinfs = $cwd . "\/" . $hashfilecelexicsinfs;
    $hashfilecelexicsstructs = $cwd . "\/" . $hashfilecelexicsstructs;
}
if ($ziterations)
{
    $hashfilecelexstemallomorphs = $cwd . "\/" . $hashfilecelexstemallomorphs;
}
if ($nlevenshtein)
{
    $hashfilecelexdissimallomorphs = $cwd . "\/" . $hashfilecelexdissimallomorphs;
}

foreach $sFilename (@aFileList)
{
    $base = basename($sFilename);
    $hashfilecompounds = "$pathname\/$base\_compounds\_hash";
    $hashfileanalyses = "$pathname\/$base\_analyses$snitstring\_hash";
    $outputfileanalyses =  "$pathname\/$base\_analyses$snitstring.out";

    
    if ($flagcelex) # add celex splits, change file names
    {
	print "Also build deep CELEX analyses for $sFilename\n";
	$hashfileanalyses = "$pathname\/$base\_analyseswithcelex$snitstring\_hash";  #output from build is input here
	$outputfileanalyses =  "$pathname\/$base\_analyseswithcelex$snitstring.out";
    }
    else 
    {
	#currently nothing
    }
    
    print "Output of hash in $hashfileanalyses ...\n";
    
    print "hashfilecompounds = $hashfilecompounds, hashfileallcompounds = $hashfileallcompounds\n";


    if ($niterations == 0 && $ziterations == 0)
    {
	print "Analyses for $sFilename finished.\n\n";
	my $end_run = time();
	my $run_time = $end_run - our $start_run;
	print "Job took $run_time seconds\n";
	next;
    }
    print "hashfilecelexstemallomorphs: $hashfilecelexstemallomorphs \n";

    print "hashfilecelexpos: $hashfilecelexpos\n";
    
    buildanalyses($hashfilecompounds, $hashfileallcompounds, $hashfileanalyses, $niterations, $ziterations, $nlevenshtein, $flaginfosintree, $flagpos, $flagparstyle, $flagcelex, $hashfilecelexicsinfs, 
		  $hashfilecelexlistinverted, $hashfilecelexicsstructs, $hashfilecelexstemallomorphs, $hashfilecelexdissimallomorphs, $hashfilecelexpos);
    print " ... Output of text format to $outputfileanalyses\n";
    output_of_tied_hash_witharraysinlines($hashfileanalyses, $outputfileanalyses);
}

if ($niterations == 0 && $ziterations == 0)
{
    print "All analyses finished.\n\n";
    my $end_run = time();
    my $run_time = $end_run - our $start_run;
    print "Job took $run_time seconds\n";
    exit(0);
}
print "Start to build deep analyses for all compounds\n";

    print "hashfilecelexpos: $hashfilecelexpos\n";


buildanalyses($hashfileallcompounds, $hashfileallcompounds, $hashfileallanalyses, $niterations, $ziterations, $nlevenshtein, $flaginfosintree, $flagpos, $flagparstyle, $flagcelex, $hashfilecelexicsinfs, 
	      $hashfilecelexlistinverted, $hashfilecelexicsstructs, $hashfilecelexstemallomorphs, $hashfilecelexdissimallomorphs, $hashfilecelexpos);
print "Output of analyses in hashfile: $hashfileallanalyses \n";
output_of_tied_hash_witharraysinlines($hashfileallanalyses, $outputfileallanalyses);
print "Output of analyses: $outputfileallanalyses \n";

print "All analyses finished.\n\n";
                 
my $end_run = time();
my $run_time = $end_run - our $start_run;
print "Job took $run_time seconds\n";
exit(0);

##### Subroutines

sub output_of_tied_hashs {
    my ($inputhashfile, $outputtextfile) = @_;
    my (%hinput,
	@keys,
	$key,
	$value,
	@valuearray,
	$db,
	);

   $db = tie (%hinput, 'MLDBM' , $inputhashfile, O_RDONLY, 0666, $DB_BTREE);

    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    
    open (AUSGABE, ">$outputtextfile") || die "Fehler! ";
    @keys = natkeysort { $_} keys %hinput;

    foreach $key (@keys)
	{
	    $value = $hinput{$key};
            print AUSGABE "$key\\\\$value\n";
	}
    close AUSGABE;
    undef $db;   
    untie (%hinput);
    return ("$outputtextfile");
}


sub addinfinitivestems{
    my ($ics, @positions) = @_;
    my (@ics, 
	$n,
	$verb, 
	$newics);
    @ics = split /[|]/, $ics;
    # print "@ics @positions\n";
    foreach $n (@positions)
    {
	$verb = $ics[$n];
	$verb .= "en";
	$verb =~ s/(eie[lr])en$/$1n/;#feiern
	$verb =~ s/([^i]e[lr])en$/$1n/;
	$verb =~ s/(que[lr])n$/$1en/;#queren
	$ics[$n] = $verb;
    }
    $newics = join ('|', @ics);
    return $newics;
}


sub output_of_tied_hash_witharraysinlines {
    my ($inputhashfile, $outputtextfile) = @_;
    my (%hinput,
	@keys,
	$key,
	$value,
	@valuearray,
	$ref,
	$db,
	);

    # print "Output of tied hash with arrays ...\n";	
	
    $db = tie (%hinput, 'MLDBM' , $inputhashfile,  O_RDONLY, 0666, $DB_BTREE);
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');

    open (AUSGABE, ">$outputtextfile") || die "Fehler! ";
    
    @keys = natsort keys %hinput;
    foreach $key (@keys)
    {
      #     print "$key\n";
	    @valuearray = @{$hinput{$key}};

	    foreach $ref (natsort @valuearray)
	    {	
	
		print AUSGABE "$key\t$ref\n";
		
	    }
	}
    close AUSGABE;
    undef $db;   
    untie (%hinput);
    return ("$outputtextfile");
}


sub mycartesian {
    my @sets = @_;
    # base case
    if (@sets == 0) {
        return ([]);
    }
    my @first = @{$sets[0]};
    # recursive call
    shift @sets;
    my @rest = mycartesian(@sets);
    my @result = ();
    foreach my $element (@first) { 
        foreach my $product (@rest) { 
            my @newSet = @{$product};
            unshift (@newSet, $element);
            push (@result, \@newSet);
        }
    }
    return @result;
}


sub insert_fillerletters{
    my ($orthform, $set) = @_;
    my ($setstr,
	$part,
	$lengthpart,
	$orthcopy,
	$firstuml,
#	$letter,
	$uml,
	$inpart,
	$partcopy,
	$partcopy2,
	$pc,
	@allpartcopies,
	$substrcomplete,
	$startofsubstr,
	$fillerletters,
	$diffstr,
	$diffa,
	$diffb,
	$ad,
	$newvowel,
	$neworthcopy,
	$overlap,
	$common1,
	$common2,
#	@commons,
	@aoutputset,
	$outputset);


     my %umlauts = (
	'ä' => 'a',
	'ö' => 'o',
	'ü' => 'u',
	'Ä' => 'A',
	'Ö' => 'O',
	'Ü' => 'U',
	 );
    
     my %exceptions = (
	 'Album' => 'Alben',
	 'Datum' => 'Daten',
	 'Evangelium' => 'Evangelien',
	 'Forum' => 'Foren',
	 'Gremium' => 'Gremien',
	 'Johannes' => 'Johannis',
	 'Kriterium' => 'Kriterien',
	 'Medium' => 'Medien',
	 'Mysterium' => 'Mysterien',
	 'Studium' => 'Studien',
	);

    
    print "Orthform/set: $orthform / @$set\n";
    $orthcopy = lc $orthform;

    $setstr = lc (join ('', @$set));
    if ($orthcopy eq $setstr) # if the lower case strings are equal, nothing is missing
    {
#	print "no difference\n";
	return $set;
    }

#remove blank e.g. in "Acht hundert" as part of Achthundertmeterrennen
    
    $setstr =~ s/ //g;
    if ($orthcopy eq $setstr) # if the lower case strings are equal, nothing is missing
    {
#	print "no difference\n";
	return $set;
    }
    
    #print "Setstr: $setstr\n";

    # if numbers, add - and compare
    $setstr =~ s/(\d+)x(\d+)/$1x$2\-/g;
    #print "Setstr: $setstr\n";

    if ($orthcopy eq $setstr) # if the lower case strings are equal, nothing is missing
    {
#	print "no difference\n";
	return $set;
    }

    else # we have to find the differences
    {
	@aoutputset = ();
        PART: foreach $part (@$set)
	{
	    #	    print "Part: $part\n";
	    # create an array with all possible variations
	    @allpartcopies = ();
	    push (@allpartcopies, $part);
	    $partcopy = lc $part;
	    push (@allpartcopies, $partcopy);
	  
	    ($partcopy2 = $partcopy) =~ s/(\d+) x (\d+)/$1x$2/g; # first pull together 4x100 cases 
	    push (@allpartcopies, $partcopy2);

	   ($partcopy2 = $partcopy) =~ s/(\d+) x (\d+) /$1x$2\-/g; # first pull together 4x100 cases, variation 
	    push (@allpartcopies, $partcopy2);

	    ($partcopy2 = $partcopy) =~ s/ /\-/g; # Variation for blanks in part

	    push (@allpartcopies, $partcopy2);
	    
	    ($partcopy2 = $partcopy) =~ s/ /s/g; # Variation for blanks in part

	    push (@allpartcopies, $partcopy2);
	  
	    ($partcopy2 = $partcopy) =~ s/\-//g;
	    
	    push (@allpartcopies, $partcopy2);
	    
	    ($partcopy2 = $partcopy) =~ s/ //g;
	    
	    push (@allpartcopies, $partcopy2);
	    
	    #	    print "Partcopy2: $partcopy2\n";

	    # generate template with umlaut under certain conditions
	    
	    $firstuml = firstidx {$_ =~/[äöüÄÖÜ]/} split (//, $orthcopy);
	    
	    if ($firstuml > 0 && $firstuml <= ((length $part) - 1)) # found umlaut in the part
	    {
		$inpart = substr $part, $firstuml, 1;
#		print "Firstuml: $firstuml inpart: $inpart\n";
		$uml = substr $orthcopy, $firstuml, 1;
		$newvowel = $umlauts{$uml};

		if ($inpart eq $newvowel)   
		{
#		    print "worthwhile generating another template for $part with $inpart and $orthcopy with $uml: ";
		    $partcopy2 = $partcopy;
		    substr($partcopy2, $firstuml, 1) =  $uml;
#		    print "$partcopy2\n";
		    push (@allpartcopies, $partcopy2);
		}
	    }

	    @allpartcopies = uniq(@allpartcopies);
	    
    	    if ($orthcopy eq '') # empty but there is still a part here
	    {
	        print "Maybe something went wrong with $orthform and "; print join (",", @$set); print " as constituents. Please have a look at the GermaNet data.\n";
		return $set;		
	    }

	    # case 1: $part is completely included in $orthcopy, from the beginning

	    foreach $pc (@allpartcopies) # work through all variations of the specific part
	    {
		$lengthpart = length ($pc);
		$substrcomplete = substr($orthcopy, 0, $lengthpart);
		
		if (exists $exceptions{$pc} && ($substrcomplete eq lc($exceptions{$pc})) )
		{
		   push (@aoutputset, $part);
#		   print "Exception\n";
		   $orthcopy = substr($orthcopy, $lengthpart); 
		   next PART;
		}
	            			
		if ($substrcomplete eq $pc)
		{
		    push (@aoutputset, $part);
#		  #  print "completely found $part as $substrcomplete in $orthcopy\n";
		    $orthcopy = substr($orthcopy, $lengthpart);
		    next PART;
		}
	    }
	

	    # case 2: complete $part does not start from the beginning, because there is a Fuge
	   
	    if (($startofsubstr = index($orthcopy, $partcopy)) && ($startofsubstr > 0))
	    {
	#	print "Orthcopy/part: $orthcopy / $part \n";
		$fillerletters = substr($orthcopy, 0, $startofsubstr);
#		print "FL: $fillerletters\n";
	       
		push (@aoutputset, $fillerletters);		
		push (@aoutputset, $part);
		$orthcopy = substr($orthcopy, length $fillerletters);
#		print "Orthcopy1: $orthcopy\n";
		$orthcopy = substr($orthcopy, $lengthpart);
#		print "Orthcopy2: $orthcopy\n";
	    }

	    # case 3: $part is longer, e.g. a verb like "bauen" in "bauen|Zeit", but start from the beginning
	    
	    elsif ($diffstr = String::Diff::diff_fully($orthcopy, $partcopy2))  
	    {
		$common1 = 'u' eq (@{ $diffstr->[0]})[0][0];
		$common2 = 'u' eq (@{ $diffstr->[1]})[0][0];

# all start with the common string

		if ($common1 && $common2) # something common really found at the start
		{    	
		    print "common1: $common1\n";
		    print Dumper (\@{ $diffstr->[0]});
		    print Dumper (\@{ $diffstr->[1]});
		    $overlap = (@{ $diffstr->[0]})[0][1];
	   
		    $diffa = (scalar (@{ $diffstr->[0]})) > 1 ? (@{ $diffstr->[0]})[1][1] : ''; # if more than one element, else '';
		    $diffb = (scalar (@{ $diffstr->[1]})) > 1 ? (@{ $diffstr->[1]})[1][1] : ''; # if more than one element, else '';

		    # my $diffb =  (@{ $diffstr->[1]})[1][1];
		 #    print "Orthcopy: $orthcopy, partcopy2: $partcopy2, Overlap: $overlap, Diffa: $diffa,  Diffb: $diffb *\n";
		    
		    # here exclude cases with unsystematic entries such as
		    # Orthcopy: arbeitnehmerüberlassungsgesetz, partcopy2: arbeitsnehmerüberlassung, Overlap: arbeit

		    $ad = 0;
		    if ($diffa)
		    {
			$ad = substr $diffa, 0, 1;
			print "First letter: $ad\n";
		    }
		    
		    
		    $newvowel = exists $umlauts{$ad} ? $umlauts{$ad} : 0;
		    
		    print "Newvowel: $newvowel\n";
		       
		    if ($newvowel && $ad && ($diffb eq $newvowel) ) # Städte Stadt
		    {
			print "Umlaute: $newvowel\n";
			$neworthcopy = substr $orthcopy, (length $overlap) + (length $newvowel);
			$neworthcopy = $overlap . $newvowel . $neworthcopy;
		#	print "neworthcopy: $neworthcopy\n";
			$diffstr = String::Diff::diff_fully($neworthcopy, $partcopy2);
		#	print Dumper (\@{ $diffstr->[0]});
		#	print Dumper (\@{ $diffstr->[1]});
			
			$overlap = (@{ $diffstr->[0]})[0][1];
		   
			$diffa = (scalar (@{ $diffstr->[0]})) > 1 ? (@{ $diffstr->[0]})[1][1] : ''; # if more than one element, else '';
			$diffb = (scalar (@{ $diffstr->[1]})) > 1 ? (@{ $diffstr->[1]})[1][1] : ''; # if more than one element, else '';

		#	print "neworthcopy: $neworthcopy, partcopy2: $partcopy2, Overlap: $overlap, Diffa: $diffa,  Diffb: $diffb *\n";
			$orthcopy = $neworthcopy;
		    }
		    
		    if (((length $partcopy2) - (length $overlap) < 3) || ($diffb eq 'ieren'))  # bauen, bau; kondensieren, Kondens
		    {
			push (@aoutputset, $part);
			# print "orthcopy: $orthcopy, partcopy2: $partcopy2, Overlap: $overlap *\n";
			$orthcopy = substr($orthcopy, length $overlap);
		    }
		    else
		    {
			push (@aoutputset, $part);
		#	print "Orthcopy: $orthcopy partcopy2: $partcopy\n";		
		
			if ((length $orthcopy) >= (length $partcopy2))
			{
			    $orthcopy = substr($orthcopy, length $partcopy2); #sth went wrong here, FL definitively too long
			}
			else
			{
			    $orthcopy = '';
			}
			
		    }
		}
		else # nothing common in the start just push what there is
		{
		    push (@aoutputset, $part);
		    # print "Orthcopy: $orthcopy, partcopy2: $partcopy2\n";
		    if ((length $orthcopy) >= (length $partcopy2))
		    {
			$orthcopy = substr($orthcopy, length $partcopy2);
		    }
		    else
		    {
			$orthcopy = '';
		    }
		}
	    }
	}
	$outputset = \@aoutputset;
#	print "Aoutputset: @aoutputset\n";
	return ($outputset);
    }
}

## returns $outputhashfile with Hash of compounds and their analyses

sub buildanalyses {
    my ($inputhashfile, $hashfileallcompounds, $outputhashfile, $nitlimit, $zitlimit, $nlevenshtein, $flaginfosintree, $flagpos, $flagparstyle, $flagcelex, $hashfilecelexicsinfs, 
	$hashfilecelexlistinverted, 
	$hashfilecelexicstructs, $hashfilecelexstemallomorphs, $hashfilecelexdissimallomorphs, $hashfilecelexpos) = @_;
    my ($db1,
	$db2,
	$db3,
	$db4,
	$db5,
	$db6,
	$dballo,
	$dbdiss,
	$dbpos,
	%hinput,
	%houtput,
	$orthform,
	$ref_list,
	$ref_acompounds,
	$ref_structure,
	@list,
	@sortlist,
	@newlist,
	@acompounds,
	$compound,
	@anewcompound,
	@anewcompounds,
	$newcompound,
	@aconstituents,
	$constituent,
	$constituentoriginal,
	$pos,
	$nit,
	$linginfo,
	@acartesianresult,
	$set,
	$setstring,
	@allsetstrings,
	);
    
    use vars qw (%hcompoundsall);

    print "flagpos: $flagpos, nitlimit: $nitlimit\n";
   
    print "Inputfile: $inputhashfile\n";
    $db1 = tie (%hinput, 'MLDBM' , $inputhashfile,  O_RDONLY, 0666, $DB_BTREE);
    Dumper($db1->{DB});
    $db1->{DB}->Filter_Push('utf8');

    # hcompounds comprises all compounds
    print "all compounds in $hashfileallcompounds\n";
    $db2 = tie (%hcompoundsall, 'MLDBM' , $hashfileallcompounds,  O_RDONLY, 0666, $DB_BTREE);
    Dumper($db2->{DB});
    $db2->{DB}->Filter_Push('utf8');

    $db3 = tie (%houtput, 'MLDBM', $outputhashfile,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($db3->{DB});
    $db3->{DB}->Filter_Push('utf8');

    if ($flagcelex)
    {
	print "Invertedfile: $hashfilecelexlistinverted\n";
	$db4 = tie (%hcelexlisti, 'MLDBM' , $hashfilecelexlistinverted,  O_RDONLY, 0666, $DB_BTREE);
	Dumper($db4->{DB});
	$db4->{DB}->Filter_Push('utf8');    
    
	$db5 = tie (%hcelexicsa, 'MLDBM' , $hashfilecelexicsinfs,  O_RDONLY, 0666, $DB_BTREE);
	Dumper($db5->{DB});
	$db5->{DB}->Filter_Push('utf8');

	print "IC structures in $hashfilecelexicstructs\n";
	$db6 = tie (%hcelexicstructsa, 'MLDBM' , $hashfilecelexicstructs,  O_RDONLY, 0666, $DB_BTREE);
	Dumper($db6->{DB});
	$db6->{DB}->Filter_Push('utf8');
    }
	
    if ($zitlimit)
    {
	print "hashfilecelexstemallomorphs: $hashfilecelexstemallomorphs\n";
	$dballo = tie (%hzallo, 'MLDBM', $hashfilecelexstemallomorphs,  O_RDONLY, 0666, $DB_BTREE);
	Dumper($dballo->{DB});
	$dballo->{DB}->Filter_Push('utf8');
    }
    
  if ($nlevenshtein)
    {
	$dbdiss = tie (%hzdiss, 'MLDBM', $hashfilecelexdissimallomorphs,  O_RDONLY, 0666, $DB_BTREE);
	Dumper($dbdiss->{DB});
	$dbdiss->{DB}->Filter_Push('utf8');

#	print "hashfilecelexpos: $hashfilecelexpos\n";
	
	$dbpos = tie (%hcelexposa, 'MLDBM', $hashfilecelexpos,  O_RDONLY, 0666, $DB_BTREE);
	Dumper($dbpos->{DB});
	$dbpos->{DB}->Filter_Push('utf8');
    }
    
    while(($orthform, $ref_acompounds) = each(%hinput))
    {
	$nit = 0;
	@acompounds = @$ref_acompounds;
	@anewcompounds = ();
	
	 print "ba: in hash: $orthform @acompounds \n";
	
	foreach $compound (@acompounds)
	{
	    print "compound: $compound\n";
	    @anewcompound = ();
	    @aconstituents =  split /[|]/, $compound;
	    foreach $constituent (@aconstituents) 
	    {
		print "constituent: $constituent";

		if ($flagpos)
		{
		    $constituentoriginal = $constituent;
		    $constituent =~ /(.*)\_(.*)$/;
		    $constituent = $1;
		    $pos = $2;
		    print ", pos: $pos";    
		}
		print "\n";    

		if (exists $hcompoundsall{$constituent})
		{
		    print "exists\n";
		    $nit++;
		    print "nit: $nit\n";
		    $ref_list = $hcompoundsall{$constituent}; 
		    if ($nit >= $nitlimit) # no deeper search
		    {
			my @alist = @{$ref_list};
			print "No deeper search List: @alist\n";
			if ($flaginfosintree && $flagpos)
			{
			    $linginfo = "*" . $constituent . "_" . $pos .  "*";
			    @alist = map { "($linginfo $_)" } @alist;
			}			
			elsif ($flaginfosintree)
			{
			    $linginfo = "*" . $constituent . "*";
			    @alist = map { "($linginfo $_)" } @alist; 
			}
			elsif($flagpos)
			{
			    $linginfo = "*" . "_". $pos . "*";
			    @alist = map { "($linginfo $_)" } @alist; 
			}
			else
			{
			    @alist = map { "($_)" } @alist;
			}
			
			push (@anewcompound, \@alist);
#			print "2 anewcompound:\n";
#			print Dumper (@anewcompound);
		    }
		    else # deeper analysis
		    {
			my @alist = @{$ref_list};
			print "Deeper search: @alist, nitlimit: $nitlimit\n";
			
			$ref_structure = 
			    deep_buildanalyses($ref_list, $nit, $nitlimit, 
					       $zitlimit, $nlevenshtein, $flaginfosintree, 
					       $flagpos, $flagparstyle, $flagcelex, 
					       $hashfilecelexlistinverted, 
					       $hashfilecelexstemallomorphs, 
					       $hashfilecelexdissimallomorphs,
					       $hashfilecelexpos);
			@alist = @{$ref_structure};
			
			if ($flaginfosintree && $flagpos)
			{
			    $linginfo = "*" . $constituent . "_" . $pos .  "*";
			    @alist = map { "($linginfo $_)" } @alist;
			}			
			elsif ($flaginfosintree)
			{
			    $linginfo = "*" . $constituent . "*";
			    @alist = map { "($linginfo $_)" } @alist; 
			}
			elsif($flagpos)
			{
			    $linginfo = "*" . "_". $pos . "*";
			    @alist = map { "($linginfo $_)" } @alist; 
			}
			else
			{
			    @alist = map { "($_)" } @alist;
			}
			push (@anewcompound, \@alist);
		    }
		}
		
		else # does not exist
		{
		    if ($flagcelex)
		    {
		    #lookup in CELEX
			my @alist = ();
			#if flagpos use appended form
			if ($flagpos)
			{
			    push (@alist, $constituentoriginal);
			}
			else
			{
			push (@alist, $constituent);
			}
			print "Alist: @alist\n";
			$ref_structure = deep_addcelexsplits(\@alist, $nit, 0, $nitlimit, $zitlimit, $nlevenshtein, $flaginfosintree, $flagparstyle,$flagpos);
			@alist = @{$ref_structure};
			push (@anewcompound, \@alist);
		    }
		    
		   else  
		    {
			my @alist = ();
			print "not found\n";
			if($flagpos)
			{
			    push (@alist, $constituentoriginal);
			}
			else
			{
			   push (@alist, $constituent);  
			}
			print "alist: @alist\n";
			push (@anewcompound, \@alist);	
		      # push (@anewcompound, [$constituent]);
		    }
		}
	    }
	    
	    @acartesianresult = mycartesian (@anewcompound);
	    #print "acartesianresult for analyses:\n";
	    #print Dumper (@acartesianresult);
	    @allsetstrings = ();
	    for $set (@acartesianresult)
	    {
		my @alist = @$set;
		$setstring = join ('|', @alist);
		print "Set: $setstring\n";
		
		if (($flagparstyle) && ($#alist > 0)) #at least two elements  
		{
		    $setstring =  join ('',  map { if ($_ !~ /^\(.*\)/) {"($_)"} else {"$_"} } @alist);
		    #put in parentheses what is not in parentheses.
		}
		print "Set: $setstring\n";
		push (@allsetstrings, $setstring);
		# put in hash
	    }
	    
	    if (exists $houtput{$orthform})
	    {
		$ref_list = $houtput{$orthform}; 
		@list = @$ref_list;
		push(@list, @allsetstrings);
		@sortlist = uniq (sort @list);
		$ref_list = \@sortlist;
	    }
	    else
	    {
		@sortlist = uniq (sort @allsetstrings);
		$ref_list = \@sortlist;
	    } 
	    $houtput{$orthform} = $ref_list;
	}
    }
    
    undef $db1;
    untie (%hinput);

    undef $db2;
    untie (%hcompoundsall);
    
    undef $db3;
    untie (%houtput);

    if ($flagcelex)
    {
	undef $db4;
	untie (%hcelexlisti);
	undef $db5;
	untie (%hcelexicsa);
	
	undef $db6;
	untie (%hcelexicstructsa);
    }
    
    if ($zitlimit)
    {
	undef $dballo;
	untie (%hzallo);
    }

    if ($nlevenshtein)
    {
	undef $dbdiss;
	untie (%hzdiss);
	undef $dbpos;
	untie (%hcelexposa);
    }
  

    return ($outputhashfile);
}

#$ref_array: the list of compsplits from above to be further analysed
sub deep_buildanalyses{
    my ($ref_array, $nit, $nlimit, $zlimit, $nlevenshtein, $flaginfosintree, $flagpos, $flagparstyle, $flagcelex, $hashfilecelexlistinverted,
	$hashfilecelexstemallomorphs, $hashfilecelexdissimallomorphs, $hashfilecelexpos) = @_;
    my(@aconstfromabove,
       @anewcomp,
       @anewcomps,
       $const,
       $constofconst,
       $constofconstoriginal,
       @aconsts,
       $ref_listofdeep,
       $ref_structure,
       @acartesianresultdeep,
       @allsetstringsdeep,
       $setdeep,
       $setstringdeep,
       $linginfo,
       $pos,
	);
    
    @aconstfromabove = @$ref_array;
    print "deep analysis of @aconstfromabove \n";
    @anewcomps = ();
    @anewcomp = ();
    
    foreach $const (@aconstfromabove)
    {
	print "Const: $const\n";
	$nit++;
	@aconsts =  split /[|]/, $const;
	foreach $constofconst (@aconsts)
	{
	    print "constofconst: $constofconst\n";
	    $constofconstoriginal = $constofconst;
	    
	    if ($flagpos)
	    {
		
		$constofconst =~ /(.*)\_(.*)$/;
		$constofconst = $1;
		$pos = $2;
		print "constofconst: $constofconst\n";
	    }
	    
	    if (exists $hcompoundsall{$constofconst})
	    {
		#print "**\n";
		$ref_listofdeep = $hcompoundsall{$constofconst}; 
		if ($nit == $nlimit) # no deeper search
		{
		    
		    my @alist = @{$ref_listofdeep};
		    #print "*** @alist\n";

		    if ($flaginfosintree && $flagpos)
		    {
			$linginfo = "*" . $constofconst . "_" . $pos .  "*";
			@alist = map { "($linginfo $_)" } @alist;
		    }
		    elsif ($flaginfosintree)
		    {
			print "fit\n";
			$linginfo = "*" . $constofconst . "*";
			@alist = map { "($linginfo $_)" } @alist; 
		    }
		    elsif($flagpos)
		    {
			$linginfo = "*" . "_". $pos . "*";
			@alist = map { "($linginfo $_)" } @alist; 
		    }
		    else
		    {
			print "else\n";
			@alist = map { "($_)" } @alist;
		    }
		    
		    push (@anewcomp, \@alist);
		}
		else
		{
		    $ref_structure = 
			deep_buildanalyses($ref_listofdeep, $nit, $nlimit, $zlimit, $nlevenshtein,
					   $flaginfosintree, $flagpos, $flagparstyle, $flagcelex,
					   $hashfilecelexlistinverted, 
					   $hashfilecelexstemallomorphs, 
					   $hashfilecelexdissimallomorphs, $hashfilecelexpos);
		    my @alist = @{$ref_structure};	

		    if ($flaginfosintree && $flagpos)
		    {
			$linginfo = "*" . $constofconst . "_" . $pos .  "*";
			@alist = map { "($linginfo $_)" } @alist;
		    }
		    elsif ($flaginfosintree)
		    {
			$linginfo = "*" . $constofconst . "*";
			@alist = map { "($linginfo $_)" } @alist; 
		    }
		    elsif($flagpos)
		    {
			$linginfo = "*" . "_". $pos . "*";
			@alist = map { "($linginfo $_)" } @alist; 
		    }
		    else
		    {
			@alist = map { "($_)" } @alist;
		    }		    
		    push (@anewcomp, \@alist);
		}
	    }	    
	    else # does not exist
	    {
		if ($flagcelex)
		{
		    #lookup in CELEX
		    my @alist = ();
		    push (@alist, $constofconstoriginal);
		    print "Alist: @alist\n";
		    $ref_structure = deep_addcelexsplits(\@alist, $nit, 0, $nlimit, $zlimit, $nlevenshtein, $flaginfosintree, $flagparstyle, $flagpos);
		    @alist = @{$ref_structure};	
		    push (@anewcomp, \@alist);
		}
		else
		{
		    if($flagpos)
		    {
			push (@anewcomp, [$constofconstoriginal]);
		    }
		    else
		    {
			push (@anewcomp, [$constofconst]); # reference to array with constituent
		    }
		}
	    } # end else does not exist
	}
	print "anewcomp: @anewcomp\n";
	@acartesianresultdeep = mycartesian (@anewcomp);
	print Dumper (\@acartesianresultdeep);
	@allsetstringsdeep = ();
	
	for $setdeep (@acartesianresultdeep)
	{
	    my @alist = @$setdeep;
	    $setstringdeep = join ('|', @alist);
	    print "Setstringdeep: $setstringdeep\n";
	    
	    #   if (($flagparstyle) && (! $flagcelex) && ($#alist > 0)) #at least two elements
	    if ($flagparstyle && ($#alist > 0)) #at least two elements
	    {
		$setstringdeep =  join ('',  map { if ($_ !~ /^\(.*\)/) {"($_)"} else {"$_"} } @alist);
	    }
	    print "Setstringdeep: $setstringdeep\n";
	    push (@allsetstringsdeep, $setstringdeep);
	}
	push (@anewcomps, @allsetstringsdeep);
	@anewcomp = ();
    }
#	print "result of deep analysis: @anewcomps\n";
	return(\@anewcomps);
}


sub deep_addcelexsplits{
    my ($ref_array, $nit, $zit, $nlimit, $zlimit, $lev, $flaginfosintree, $flagparstyle, $flagpos) = @_;
    my(@aconstfromabove,
       @anewcomp,
       @anewcomps,
       $const,
       $constofconst,
       $pos,
       $currentn,
       $currentz,
       @aconsts,
       $derivorcomp,
       $derivorcompcopy,
       $derivorcompstruct,
       $derivorcompstructcopy,
       @derivorcompcopy,
       @derivorcompstructcopy,
       @derivorcompplusstruct,
       $ref_listofdeep,
       $ref_structure,
       @acartesianresultdeep,
       @allsetstringsdeep,
       $setdeep,
       $setstringdeep,
       $indexc,
       $ref_indexc,
       $linginfo,
       $flaglev,
);

#    print "infosintrees: $flaginfosintree\n";
    
    @aconstfromabove = @$ref_array;
    print "dac: deep analysis of @aconstfromabove \n";
    @anewcomps = ();
   
    foreach $const (@aconstfromabove)
    {
	$currentn = $nit + 1;
	$currentz = $zit;
	@aconsts =  split /[|]/, $const;
	foreach $constofconst (@aconsts)
	{
	    $flaglev = 0;
	    print "celex constofconst: $constofconst\n";
	    
	    if ($flagpos)
	    {	
		$constofconst =~ /(.*)\_(.*)$/;
		$constofconst = $1;
		$pos = $2;
		print "constofconst: $constofconst\n";
	    }
	   
	    if (exists $hcelexlisti{$constofconst}) # if entry in inverted index of CELEX
	    {
		$ref_indexc = $hcelexlisti{$constofconst};
		$indexc = @$ref_indexc[0];
	#	print "indexc: $indexc\n";
		
		$derivorcomp = $hcelexicsa{$indexc};
		print "derivorcomp: $derivorcomp\n";
		if ($zlimit && exists $hzallo{$indexc}) # if a conversion and zlimit
		{    
		    $currentz = $zit + 1;
		    print "Deep SA in conversion $currentz $constofconst $derivorcomp\n";
		    if ($currentz >= $zlimit)  # if the limit is reached just change the general limit
		    {
			$currentn = $nlimit;
		    }
		}
		if ($lev && exists $hzdiss{$indexc})
		{
		    # $zit = 1;
		    print "lev: $lev\n";	
		    print "Too dissimilar forms according to threshold: $constofconst\n Do not take $derivorcomp. ";
		    $derivorcomp = $constofconst; #e.g. äsen instead of Aas|en
		  #  $currentn = $nlimit;
		  #  $flaglev = "T"; # later take pos of constofconst and not of derivorcomp
		}
		    		
		# build-in stop (though it is a heuristics)
		if ($constofconst eq $derivorcomp) # for lev cases and "besser" etc (conversions by zero derivation) etc.
		{
		    print "stop soon at $constofconst\n";
		    $flaglev = "T"; # later take pos of constofconst and not of derivorcomp
		    $currentn = $nlimit;
		}

		if ($flagpos) # get ICstruct and append to components
		{
		    if ($flaglev eq "T")
		    {
			$derivorcompstruct = $hcelexposa{$indexc}; # the pos of the part, do not analyse the structure
		#	print "**T $indexc $derivorcompstruct of $constofconst\n";
		    }
		    else
		    {
			$derivorcompstruct = $hcelexicstructsa{$indexc}; # the pos of the structure 
		    }
		    print "ICstruct of DC: $derivorcompstruct\n";
		    @derivorcompcopy = split /[|]/, $derivorcomp;
		    @derivorcompstructcopy = split //, $derivorcompstruct;
		    @derivorcompplusstruct = pairwise {$a . "\_" . $b} @derivorcompcopy, @derivorcompstructcopy;
		    $derivorcomp = join ('|', @derivorcompplusstruct);
		    print "New derivorcomp: $derivorcomp\n";
		}

		if ($currentz >= $zlimit) # no deeper search and treat the last entry like a monomorphemic form
		{
		    my @alist = ();
		    if ($flagpos)
		    {
			print "Do not analyze $derivorcomp, use $constofconst instead.\n";
			$constofconst .= "_" . $pos;
		    }		    
		    push (@alist, $constofconst); 
 		    push (@anewcomp, \@alist);
		}

		elsif ($currentn >= $nlimit) # no deeper search
		{
		    print "no deeper search for $derivorcomp\n";
		    $setstringdeep = $derivorcomp;		    
		    my @alist = split /[|]/, $derivorcomp; # just in case there are splits
		    if ($flagparstyle && ($#alist > 0)) #at least two elements
		    {
			$setstringdeep =  join ('',  map { if ($_ !~ /^\(.*\)/) {"($_)"} else {"$_"} } @alist);
		    }
		    print "Setstringdeep: $setstringdeep\n";
		    @alist = ();
		    push (@alist, $setstringdeep);
		    
		    if ($flaglev)
		    {
			@alist = map { "($_)" } @alist;
			print "Flaglev alist: @alist\n";
		    }
					    
		    elsif ($flaginfosintree && $flagpos)
		    {
			$linginfo = "*" . $constofconst . "_" . $pos .  "*";
			@alist = map { "($linginfo $_)" } @alist;
		    }
		    elsif ($flaginfosintree)
		    {
			print "fit\n";
			$linginfo = "*" . $constofconst . "*";
			@alist = map { "($linginfo $_)" } @alist; 
		    }
		    elsif($flagpos)
		    {
			$linginfo = "*" . "_". $pos . "*";
			@alist = map { "($linginfo $_)" } @alist; 
		    }
		    else
		    {
			print "else\n";
			@alist = map { "($_)" } @alist;
		    }
		    push (@anewcomp, \@alist);
		}
		else # deeper analysis
		{
		    print "move on with deeper analysis\n";
		    my @alist = ();
		    push (@alist, $derivorcomp);
		    
		    $ref_structure = deep_addcelexsplits(\@alist, $currentn, $currentz, $nlimit, $zlimit, $lev, $flaginfosintree, $flagparstyle, $flagpos);
		    
		    @alist = @{$ref_structure};
		    
		    if ($flaginfosintree && $flagpos)
		    {
			$linginfo = "*" . $constofconst . "_" . $pos .  "*";
			@alist = map { "($linginfo $_)" } @alist;
		    }
		    elsif ($flaginfosintree)
		    {
			$linginfo = "*" . $constofconst . "*";
			@alist = map { "($linginfo $_)" } @alist; 
		    }
		    elsif($flagpos)
		    {
			$linginfo = "*" . "_". $pos . "*";
			@alist = map { "($linginfo $_)" } @alist; 
		    }
		    else
		    {
			@alist = map { "($_)" } @alist;
		    }
		    push (@anewcomp, \@alist);
		}
	    }
	    else # not in hcelexlisti (i.e. monomorphemic in CELEX or non-existing)
	    {
		print "not in inverted list\n";
		if ($flagpos)
		{
		    $constofconst .= "_" . $pos;
		}		    
		push (@anewcomp, [$constofconst]); # reference to array with constituent	
	    }
	}
	# print "anewcomp: @anewcomp\n";
	@acartesianresultdeep = mycartesian (@anewcomp);
#	print Dumper (\@acartesianresultdeep);
	@allsetstringsdeep = ();

	for $setdeep (@acartesianresultdeep)
	{
	    #  print "Setdeep: $setdeep ";
	    
	    my @alist = @$setdeep;
	    $setstringdeep = join ('|', @alist);
	    print "Setstringdeep: $setstringdeep\n";
	    
	    if (($flagparstyle) && ($#alist > 0)) #at least two elements  
	    {
		$setstringdeep =  join ('',  map { if ($_ !~ /^\(.*\)/) {"($_)"} else {"$_"} } @alist);
	    }
	    print "Setstringdeep: $setstringdeep\n";
	    push (@allsetstringsdeep, $setstringdeep);
	}
	push (@anewcomps, @allsetstringsdeep);
	@anewcomp = ();
    }
	print "result of CELEX deep analysis: @anewcomps\n";
	return(\@anewcomps);
}
