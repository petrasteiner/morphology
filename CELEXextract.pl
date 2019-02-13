=pod

=head1 NAME

<CELEXextract> Takes the refurbished CELEX database for German and extracts tree structures of complex words. Many options can be made, e.g. skip conversions or restrict the trees to a certain depth of analysis

=head1  VERSION

Draft Version

=head1 SYNOPSIS

Synopsis in CELEXextract.help

=head1 REQUIREMENTS

files GMOLoutputneworthography
      GSOLoutputneworthography

=head1 USE

Description in CELEXextract.help

=head1 ARGUMENTS

see CELEXextract.help

=head1 OPTIONS

see CELEXextract.help

=head1 DESCRIPTION

see CELEXextract.help

=head1 SUBROUTINES

=head2 output_of_tied_hashs

takes $inputhashfile and $outputtextfile
sorts keys and writes keys and value to the output

=head2 output_of_tied_hash_witharrayinlines

takes $inputhashfile and $outputtextfile
sorts keys and writes keys and value to the output
the values are arrays, these are sorted and printed
to the output file

=head2 addinfinitivestems
takes $ics: string with immediate constituents and @positions of verbs
adds infinitive stems at the positions
returns $newics

=head2 addcelexsplits
takes  $inputhashfile, 
some previously created hashfiles,
parameters for the number of analysis levels and levenshtein methods, 
flags for infosintree, pos, parenthesis style 
and writes the generated result with morphological analyses to $outputhashcelexanalysis
calls deep_addcelexsplits, mycartesian

=head2 deep_addcelexsplits
works recursively, called by addcelexsplits, 
takes an array with a word constituent from above, 
parameters for the number of analysis levels and levenshtein methods, 
the current values of these parameters
flags for infosintree and pos
calls deep_addcelexsplits, mycartesian

=head2 mycartesian
takes an array
returns the Cartesian product of the subsets of the array

=head1 DIAGNOSIS

File $sFileName could not be opened - check for path and name


=head1 CONFIGURATION AND ENVIRONMENT

Linux or Unix-like environments

=head1 DEPENDENCIES

The following modules are used:
=head1 INCOMPATABILITIES

Not known


=head1 BUGS AND LIMITATIONS

=head1 AUTHOR(S)

Petra Steiner, steiner@ids-mannheim.de

=head1 COPYRIGHT

Distribution only by Petra Steiner

=head1 

=cut

#!/usr/bin/perl -w 

# zcelex: also conversions, -it add information -pos add PoS info -par parentheses style
#n iterations, zn iterations for conversions with ablaut

#perl CELEXextract.pl -zcelex -n 5 -it -pos -par > out3003 &

use strict "vars";
use warnings;
use DB_File;
use Fcntl;

use Tie::File;

use MLDBM qw (DB_File FreezeThaw);
use Encode qw (encode decode);
use FreezeThaw;

use Data::Dumper qw(Dumper);

use List::Util qw(first none all min max);
use List::MoreUtils qw(first_index indexes uniq pairwise);
# use String::Diff;
    
$Data::Dumper::Useqq = 1;

use DBM_Filter;

use I18N::Langinfo qw(langinfo CODESET);
my $codeset = langinfo(CODESET);

# print "Codeset: $codeset\n\n";

use Encode qw(decode);

@ARGV = map { decode $codeset, $_ } @ARGV;


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

# use vars qw/%hcompoundsall/;

$| = 1;

use Sort::Key::Natural qw(natkeysort natsort);

use List::MoreUtils qw(uniq apply indexes firstidx);
use Text::Levenshtein 0.11 qw(distance);


BEGIN { our $start_run = time(); }


my($nReturnValue1,
   $nReturnValueFilename1,
   $pathname,
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
   $morphstatus,
   $icpos,
   $icstruct,
   @icstruct,
   @icstructcopy,
   $icstructcopy,
   $ics,
   @ics,
   @icscopy,
   $icscopy,
   @icsplusstruct,
   $lemmapos,
   $stem,
   $substrstem,
   $lengthsubstrstem,
   $lengthsubstrorth,
   $newlength,
   $stemallo,
   $sFilename,
   $sposFilename,
   $sicsFilename,
   $sicstructsFilename,
   $slistFilename,
   $sOutputFilename,
   $sCompoundFilename,
   $sCELEXfile,
   $niterations,
   $ziterations,
   $flagcelex,
   $flagzusammenrueckungen,
   $flaginfosintree,
   $flagpos,
   $flagparstyle,
   $nlevenshtein,
   $currentnlevenshtein,
   $levdistance,
   $nit,
   $snitstring,
   $szitstring,
   $removeforeignwords,
   $removepropernames,
   $faddfillerletters,
   $sjustCompoundsFilename,
   $hashfilecompounds,
   $hashfileanalyses,
   $hashfileallcompounds,
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
   $hashfilecompleteinvertedlist,
   $hashfilecelexlistinverted,
   $hashfilecelextrees,
   $hashfilecelexfirst,
   $hashfilecelexstemallomorphs,
   $hashfilecelexdissimallomorphs,
   %hcelexz,
   %hcelexpos,
   %hcelexics,
   %hcelexicsinfs,
   %hcelexicsstructs,
   %hcelexlist,
   %hcelexcompleteinvertedlist,
   %hcelexlistinverted,
   %hcelexfirst,
   %hcelextrees,
   %hcelexstemallos,
   %hcelexdissimallos,
   @aFileList,
   $outputfilecompounds,
   $outputfileanalyses,
   $sTokenFilename,
   $doc,
   $doc2,
   $nlexunit,
   $ncompound,
   $ncompcount,
   $lexunit,
   $lexUnitstring,
   $orthform,
   $substrorth,
   $orthformcopy,
   $stemcopy,
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
   @tagnames,
   @tagsincompound,
   @amodifiers,
   @aheads,
   @amodifiersheads,
   @acartesianresult,
   $part,
   $set,
   $refnew_setstr,  
   @aset,
   $setstring,
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
$helpfile = "CELEXextract.help";

$sInputFilename = "GMOLoutputneworthography";

$niterations = 0;
$ziterations = 0;
$flagcelex = 0;
$flagzusammenrueckungen = 0;
$flaginfosintree = 0;
$flagpos = 0;
$flagparstyle = 0;
$nlevenshtein = 0;

$cwd = `pwd`; # current
chomp $cwd;

GetOptions(
    'n=i' => \$niterations,
    'zn=i' => \$ziterations,
    'levperc=f' => \$nlevenshtein,
    'celex' => \$flagcelex,
   'zcelex' => \$flagzusammenrueckungen,
    'it' => \$flaginfosintree,
    'pos' => \$flagpos,
    'par' => \$flagparstyle,
    'h' =>  \$help,
    );

if ($help)
{
    # print "Helpfile: $helpfile";
    open my $HELP, '<:encoding(utf-8)', $helpfile or die "couldn't open $helpfile: $!"; 
    while (<$HELP>) 
    {print $_};
    close $HELP;
    exit;
}

if ($niterations)
{
    $snitstring = $niterations;
}
else
{
    $snitstring = "";
}


if ($ziterations)
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
	      # print "Could not process Line $_\n";
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


if ($nlevenshtein)
    # add these cases to %hcelexstemallos
{
    $flagzusammenrueckungen = 1;
    $hashfilecelexdissimallomorphs = "GMOLzdissimallos_hash";
# always create it, because we do not know the last levenshtein distance
    
    $sCELEXfile = GMOLoutputneworthography;
    if ( ! -e $sCELEXfile) {die "$sCELEXfile does not exist."};
    open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
    # Das Hashergebnis in eine Datei schreiben
    $db = tie (%hcelexdissimallos, 'MLDBM', $hashfilecelexdissimallomorphs,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    $linecounter = 0;
    print "\n Hash production starts for stem allomorphy with levenshtein distance in $sCELEXfile.\n";
    while(<$INPUTC>)
    {
	# print "Celex line: $_ \n";
	chomp $_;
	if ($_ =~ /^(\d+)\\(.*?)\\\d+\\Z\\(.*?\\){4}(.*?)\\(.*\\?)Y\\.*$/ )
	{
	    $index = $1;
	    $orthform = $2;
	    $stem = $4;
	  #  $currentnlevenshtein = $nlevenshtein;
	  #  $substrorth = substr ($orthform, 0, 5);
	  #  $substrstem = substr ($stem, 0, 5);
#	    $lengthsubstrorth = length($substrorth);
#	    $lengthsubstrstem = length($substrstem);

	    $orthformcopy = $orthform;
	    $stemcopy = $stem;
	    
	    $orthformcopy =~ tr/äöü/aou/;
	    $stemcopy =~ tr/äöü/aou/;
	    
	    $orthformcopy =~ s/ß/ss/;
	    $stemcopy =~ s/ß/ss/;
	    $orthformcopy = lc $orthformcopy;
	    $stemcopy = lc $stemcopy;
	    
	    $lengthsubstrorth = length($orthformcopy);
	    $lengthsubstrstem = length($stemcopy);
	    
	  #  if ($lengthsubstrorth != $lengthsubstrstem)
	   # {
	    $newlength = min($lengthsubstrorth, $lengthsubstrstem);
	    
	    $substrorth = substr ($orthformcopy, 0, $newlength);
	    $substrstem = substr ($stemcopy, 0, $newlength);
	    #		$currentnlevenshtein = $nlevenshtein - 5 + $newlength;
	    
	   # $currentnlevenshtein = $nlevenshtein - max($lengthsubstrorth, $lengthsubstrstem) +  $newlength;
	    # if ($currentnlevenshtein < 0) {$currentnlevenshtein = 1;}
	    #}
	    
	    $levdistance = distance($substrorth, $substrstem);
	   
	    if (($levdistance / $newlength) > $nlevenshtein)
	     {
		 $linecounter++;
		 # print "Large Levenshtein distance $levdistance between $orthform, $stem\n";
		 # exceptions
		 if (none {$_ eq $orthform} qw (Angebot Sicht))  # exception of exceptions
		 {
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
    
    print "stem allomorphy with levenshtein distance more or equal than $nlevenshtein in  $sCELEXfile: $linecounter , number of entries in hash (types): $hashsize \n";
    # Control output to GMOLzallos
    $sFilename = "GMOLzdissimallos";
    output_of_tied_hashs($hashfilecelexdissimallomorphs, $sFilename);
}    

	
######

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
# Das Hashergebnis in eine Datei schreiben
	$db = tie (%hcelexz, 'MLDBM', $hashfilecelexZ,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
	Dumper($db->{DB});
	$db->{DB}->Filter_Push('utf8');
	
	$linecounter = 0;
	print "\n Hash production starts for conversions in $sCELEXfile.\n";
	while(<$INPUTC>)
	{
	  # print "Celex line: $_ \n";
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
	       if ($icpos eq "V") #some changes of the stem
	       {
		   $stem .= "en";
		   $stem =~ s/(eie[lr])en$/$1n/;#feiern
		   $stem =~ s/([^i]e[lr])en$/$1n/;
		   $stem =~ s/(que[lr])n$/$1en/; # queren
		   $stem =~ s/^tuen$/tun/;
	       }
	       #print "\n $stem \n";
	       # if V with conversion from N - case ((Aal)[N])[V]
	       if (($lemmapos eq "V") && ($icpos ne "V"))
	       {
		   $stem .= "|en";
		   # print "$stem\n";
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
		   $stem =~ s/(que[lr])\|n$/$1|en/; # queren
		 }
		 if ($icpos ne "F") # lexikalized flextional forms
		 {
		    # print "Conversion entry: $stem\n";
		     $hcelexz{$index} = $stem;
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
	   # print "Celex line: $_ \n";
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
	$sposFilename = "GMOLpos";
	output_of_tied_hashs($hashfilecelexpos, $sposFilename);
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
	print "\n Hash production starts for PoS of ICs in $sCELEXfile.\n";
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
	$sposFilename = "GMOLics";
	output_of_tied_hashs($hashfilecelexics, $sposFilename);
    }

    ## and the IC structures
    $hashfilecelexicsstructs = "GMOLicstructs_hash";
    
    if (-e $hashfilecelexicsstructs) # just open it and see if it works
    {
	print "\n Loading hash file with CELEX Icstructs.\n";
	$dbicsstructs = tie (%hcelexicsstructs, 'MLDBM', $hashfilecelexicsstructs, 
		   O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $hashfilecelexicsstructs";
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
#	$nReturnValueFilename1 = put_indexedfile_in_hash($sicstructsFilename, $hashfilecelexicsstructs);
	
	$dbicsstructs = tie (%hcelexicsstructs, 'MLDBM', $hashfilecelexicsstructs, 
		   O_TRUNC|O_CREAT, 0666, $DB_BTREE);
	Dumper($dbicsstructs->{DB});
	$dbicsstructs->{DB}->Filter_Push('utf8');
	$linecounter = 0;
	print "\n Hash production starts for index-ICstruct-list in $sCELEXfile.\n";
	while(<$INPUTC>)
	{
	   # print "Celex line: $_ \n";
	    chomp $_;
	    if ($_ =~ /^(\d+)\\(.*?)\\(\d+)\\(.)\\(.*?\\){5}(.*?)\\(.*?\\){3}(.*?)\\.*$/ )
	    {
		$linecounter++;
		$index = $1;
		$morphstatus = $4;
		$orthform = $2;
		$icstruct = $6;
		$tree =$8;
		$tree =~ /^\(.*\)\[(.*)\]$/;
		$lemmapos = $1;
		if ($flagpos && $flagzusammenrueckungen && ($morphstatus eq "Z") && ($lemmapos eq "V") && ($icstruct ne "V") && (none {$_ eq $orthform} qw (zeichnen eignen entgegnen tun)))
		{ #add suffix
		 #   print "Z: $orthform\n";
		    $icstruct .= "x"; #add category for suffix
		}
		
		# print "Orthform: $orthform\n";
		$hcelexicsstructs{$index} = $icstruct;
		## add suffixes
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
	print "valid ICstructs in $sCELEXfile: $linecounter , number of entries in hash (types): $hashsize \n";
	#  Control output to GMOLicstructs
	$slistFilename = "GMOLicstructs";
	output_of_tied_hashs($hashfilecelexicsstructs, $slistFilename);   close $INPUTC;
    }

	$sicstructsFilename = "GMOLicstructs";

    
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
	 # print "$key, $value\n";

	    #only if icsstruct exists and there is a verb
	if ((exists $hcelexicsstructs{$key}) && (my @pos = indexes { $_ eq "V"}  split //, $hcelexicsstructs{$key}) )
	{
	    #print "Verb: $value\n";
	    my $newvalue = addinfinitivestems($value, @pos);
	    #print "New verb: $newvalue\n";
	    $hcelexicsinfs{$key}=$newvalue;
	}
	else
	{
	    $hcelexicsinfs{$key}=$value;
	}
    }
    
    undef $dbicsstructs;
    untie (%hcelexicsstructs);
    undef $dbics;
    untie (%hcelexics);
    
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
   
    
# now with doubles

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
		   O_RDONLY, 0644, $DB_BTREE) ||  die "Could not find file $hashfilecelexlist";
	Dumper($dblist->{DB});
	$dblist->{DB}->Filter_Push('utf8');
	undef $dblist;
	untie (%hcelexcompleteinvertedlist); 	
    }
    ####
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
    
    $hashfilecelexlistinverted =  $cwd . "\/". $hashfilecelexlistinverted;
    $hashfilecelexics = $cwd . "\/" . $hashfilecelexics;
    $hashfilecelexicsinfs = $cwd . "\/" . $hashfilecelexicsinfs;
    # for later
} # end of if $flagcelex

    push(@aFileList, $sInputFilename);
    $pathname = dirname($sInputFilename);
    $base = basename($sInputFilename);
 
    $hashfileallcompounds = "$pathname\/$base\_compounds\_hash";
    $outputfileallcompounds =  "$pathname\/$base\_compounds.out";
  #  $hashfileallanalyses = "$pathname\/$base\_analyses$snitstring\_hash";
    $outputfileallanalyses =  "$pathname\/$base\_analyses$snitstring.out";

$nfile = 0;

# the hash file with all compounds of all files

print "hashfileallcompounds: $hashfileallcompounds\n";

$db1 = tie (%hcompoundsall, 'MLDBM', $hashfileallcompounds,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
Dumper($db1->{DB});
$db1->{DB}->Filter_Push('utf8');

%hcompoundsall = ();

##################################  work through all files (usually just one but who knows)

foreach $sCELEXfile (@aFileList)  # this is a file with CELEX format, normally just GMOLoutputneworthography
{
    $nfile++;
    $base = basename($sCELEXfile);
    $sCompoundFilename = "$pathname\/$base\.constructs";
    $sjustCompoundsFilename = "$pathname\/$base\.constructforms";
    $outputfilecompounds =  "$pathname\/$base\_construct.out";
    $hashfilecompounds = "$pathname\/$base\_construct\_hash";
     
    open(SOUTPUT, '>', $sCompoundFilename) or die;
    open(SOUTPUT2, '>', $sjustCompoundsFilename) or die;

    print "hashfilecompounds: $hashfilecompounds\n";

    print "Processing the file and finding all compounds, derivations, conversions ...\n";
	
    open my $INPUTC, '<:encoding(UTF-8)', $sCELEXfile or die "couldn't open $sCELEXfile: $!";
    
    # Das Hashergebnis in eine Datei schreiben
    $db = tie (%hcelexfirst, 'MLDBM', $hashfilecompounds,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($db->{DB});
    $db->{DB}->Filter_Push('utf8');
    
    $linecounter = 0;

    print "\n Hash production starts for trees in $sCELEXfile.\n";
    %hcelexfirst = ();
    
    while(<$INPUTC>)
    {
	$ref_list = []; # reference to empty array
#	print "Celex line: $_ \n";
	chomp $_;  
	
	# find conversions and create entries
	if ($_ =~ /^(\d+)\\(.*)\\(\d+)\\Z\\(.*?\\){4}(.*?)\\(.*?)\\(.*?\\){3}(.*?)\\.*$/ )
	{
	    $linecounter++;
	    $index = $1;
	    $orthform = $2;
	    $stem = $5;
	    $icstruct = $6;
	    
	    @icstruct = split //, $icstruct;
	    # print "icstruct @icstruct\n";
	    $tree = $8;
	    $tree =~ /^\(.*\)\[(.*)\]$/;
	    # print "Tree: $tree\n";
		
	    print SOUTPUT2 "$orthform\n";
	    $lemmapos = $1;
	    if ($icstruct eq "V")
	    {
		$stem .= "en";
		$stem =~ s/(eie[lr])en$/$1n/;#feiern
		$stem =~ s/([^i]e[lr])en$/$1n/;
		$stem =~ s/(que[lr])n$/$1en/;#queren
		$stem =~ s/^tuen$/tun/;
	    }
	    # print "\n $stem \n";
	    # if V with conversion from N - case ((Aal)[N])[V]
	    if (($lemmapos eq "V") && ($icstruct eq "N"))
	    {
		$stem .= "|en";
		# print "$stem\n";
		$stem =~ s/(eie[lr])\|en$/$1|n/; #feiern
		#  print "$stem\n";
		$stem =~ s/([^i]e[lr])\|en$/$1|n/;
		$stem =~ s/(e)\|en$/$1|n/;
		$stem =~ s/(que[lr])\|n$/$1|en/;#queren

		push(@icstruct, "x"); #add category for suffix
		$stem =~ s/^tu\|en$/tun/; # no extra suffix, no addition of category	     
	    }

	    if (($lemmapos eq "V") && ($icstruct eq "O")) # duzen, siezen
	    {
		$stem .= "|zen";
		# print "O: $stem\n";
		push(@icstruct, "x"); #add category for suffix
	    }
	    
	    if ($icstruct ne "F") # now to the output, currently without lexicalized flections
	    {
		print SOUTPUT "$orthform $stem\n";		
		#  print SOUTPUT "$stem\n";
		# print "Conversion entry: $stem\n";

		if ($flagpos)
		{
		    @icscopy = split /[|]/, $stem;
		    #print "Z: @icscopy\n";
		    @icstructcopy = @icstruct;
		    @icsplusstruct = pairwise {$a . "\_" . $b} @icscopy, @icstructcopy;
		    $icscopy = join ('|', @icsplusstruct);
		   # print "icsplusstruct: @icsplusstruct\n";
		}
		else
		{
		    $icscopy = $stem;
		}
		
		if ($flagparstyle)
		{
		  #  print "parentheses for $icscopy\n";
		  #  $icscopy = parenthese_style($icscopy);
		}
		
		if (exists $hcelexfirst{$orthform})
		{
		    $ref_list = $hcelexfirst{$orthform}; 
		    @list = @$ref_list;
		    #print "Possible polylexy: $orthform\n";
		    push(@list, $icscopy);
		  
		   # @sortlist = uniq (sort @list);
		    # $ref_list = \@sortlist;
		    $ref_list = \@list;
		}
		else
		{
		    push(@{$ref_list}, $icscopy); 
		} 
		
		
		$hcelexfirst{$orthform} = $ref_list;
		
		$hcompoundsall{$index} = $icscopy;
	    }
	    else
	    {
		# print "F case conversion: $_\n";
		#	print SOUTPUT "\n";
	    }		
	} # end of process conversions
	
	elsif ($_ =~ /^(\d+)\\(.*)\\(\d+)\\C\\(.*?\\){4}(.*?)\\(.*?)\\(.*?\\){3}(.*?)\\.*$/) #constructs: derivation or compound
	{
	    $linecounter++;
	    $index = $1;
	    $orthform = $2;
	    $ics = $5;
	    $icstruct = $6;
	    @icstruct = split //, $icstruct;
	    # print "icstruct @icstruct\n";
	    $tree = $8;
	    $tree =~ /^\(.*\)\[(.*)\]$/;
	    # print "Tree: $tree\n";
	    print SOUTPUT "$orthform ";
	    print SOUTPUT2 "$orthform\n";
	    $lemmapos = $1;		 
	    $ics =~ s/\+/\|/g;	# substitute + by |	 	    
	    if (my @pos = indexes { $_ eq "V"}  @icstruct) # if there is a V within the icstructure
	    {
		# print "Verb in $orthform\n";
		my $newvalue = addinfinitivestems($ics, @pos);
		#print SOUTPUT "$newvalue\n";
		$ics = $newvalue;
	    }
	   
	    if ($lemmapos ne "F")
	    {
		# print "Construct entry: $ics\n";
	
		if ($flagpos)
		{
		    @icscopy = split /[|]/, $ics;
		 #   print "@icscopy\n";
		    @icstructcopy = @icstruct;
		    @icsplusstruct = pairwise {$a . "\_" . $b} @icscopy, @icstructcopy;
		    $icscopy = join ('|', @icsplusstruct);
		  #  print "icsplusstruct: @icsplusstruct\n";
		}
		else
		{
		    $icscopy = $ics;
		}

		if ($flagparstyle)
		{
		  #  print "parentheses for $icscopy\n";
		  #  $icscopy = parenthese_style($icscopy);
		}
		
		if (exists $hcelexfirst{$orthform})
		{
		    $ref_list = $hcelexfirst{$orthform}; 
		    @list = @$ref_list;
		  #  print "Possible polylexy $orthform\n";
		    push(@list, $icscopy);
		    #  @sortlist = uniq (sort @list);
		    #  $ref_list = \@sortlist;
		    $ref_list = \@list;
		}
		else
		{
		    push(@{$ref_list}, $icscopy); 
		}
		
		$hcelexfirst{$orthform} = $ref_list;
		$hcompoundsall{$index}= $icscopy;
		
		print SOUTPUT "$ics\n";
	    }
	    else
	    {
		print "F case compound: $_\n";
		#	print SOUTPUT "\n";
	    }	
	} # end of construct
		
	# maybe yet to come, if needed: M and F
	else
	{
	   # print "Could not process Line $_\n";
	    # print SOUTPUT "\n";
	}
    }
    close $INPUTC;
    close SOUTPUT;
    close SOUTPUT2;
    $hashsize = keys %hcelexfirst;
    undef $db;
    untie (%hcelexfirst);
    print "valid lines of inputfile: $linecounter , number of entries in hash (types): $hashsize \n";
    
    print "Output of constructs to file $outputfilecompounds\n";
    output_of_tied_hash_witharraysinlines($hashfilecompounds, $outputfilecompounds); #_construct_hash
}

undef $db1;
untie (%hcompoundsall);
 
output_of_tied_hashs($hashfileallcompounds, $outputfileallcompounds); # compound_hash

print "Output of all compounds: $outputfileallcompounds \n";

if ($flagcelex) # add celex splits
{
    foreach $sFilename (@aFileList)
    {
	print "Start to build deep CELEX analyses for $sFilename\n";

	$base = basename($sFilename);
	$hashfilecompounds = "$pathname\/$base\_construct\_hash";
	print "input from $hashfilecompounds\n";
	
	$outputhashcelexanalyses = "$pathname\/$base\_analyseswithcelex$snitstring\_hash"; # output from build is input here
	$outputfileanalyses =  "$pathname\/$base\_analyseswithcelex$snitstring.out";

	print "Output of CELEX hash in $outputhashcelexanalyses ...\n";
	
	addcelexsplits($hashfilecompounds, $hashfilecelexlistinverted, $hashfilecelexicsinfs, $hashfilecelexicsstructs, $outputhashcelexanalyses, $niterations, $ziterations, $nlevenshtein, $flaginfosintree, $flagpos, $flagparstyle, $hashfilecelexstemallomorphs, $hashfilecelexdissimallomorphs);

	print " \n... Output of text format to $outputfileanalyses\n";
	
	output_of_tied_hash_witharraysinlines($outputhashcelexanalyses, $outputfileanalyses);
    }
}

print "All analyses finished.\n\n";
                 
my $end_run = time();
my $run_time = $end_run - our $start_run;
print "Job took $run_time seconds\n";
exit(0);

#### sub routines

## currently not used
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

    $db = tie (%hfile, 'MLDBM', $soutputfile,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
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
		     print "put_indexed_file_in_hash: Could not process Line $sLine\n";
		 }
	     }
    close $INPUT;
    $hashsize = keys %hfile;
    undef $db;
    untie (%hfile);
    print "valid lines of inputfile: $linecounter , number of entries in hash (types): $hashsize \n";
    return ($soutputfile);
}


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

# later put in the path to the file to the returnValue
    return ("$outputtextfile");
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
# later put in the path to the file to the returnValue
    return ("$outputtextfile");
}


#$ics: string with immediate constituents @positions: p. of verbs
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


sub addcelexsplits {
    my ($inputhashfile, $hashfilecelexlistinverted, $hashfilecelexics, $hashfilecelexicstruct, $outputhashfile, $nitlimit, $zitlimit, $nlevenshtein, $flaginfosintree, $flagpos, 
	$flagparstyle,
	$hashfilecelexstemallomorphs, $hashfilecelexdissimallomorphs) = @_;
    my ($db1,
	$db2,
	$db2a,
	$db2b,
	$db3,
	$dballo,
	$dbdiss,
	$dbpos,
	%hinput,
	%houtput,
	
	$orthform,
	$ref_acompounds,
	$ref_structure,
	@list,
	$derivorcomp,
	$derivorcompcopy,
	$derivorcompstruct,
	$derivorcompstructcopy,
	@derivorcompcopy,
	@derivorcompstructcopy,
	@derivorcompplusstruct,
	@newlist,
	@acompounds,
	@alistnewcompound,
	$compound,
	$member,
	@anewcompound,
	@anewcompounds,
	$newcompound,
	@aconstituents,
	$constituent,
	$constituentcopy,
	$pos,
	$parenthesesbefore,
	$parenthesesafter,
	$nit,
	$zit,
	$ref_index,
	$index,
	$linginfo,
	$linginfobefore,
	$flaginfo,
	$flaglev,
	);

    
    $db1 = tie (%hinput, 'MLDBM' , $inputhashfile,  O_RDONLY, 0666, $DB_BTREE);
    Dumper($db1->{DB});
    $db1->{DB}->Filter_Push('utf8');

    #print "Opening $hashfilecelexlistinverted\n";

    $db2 = tie (%hcelexlisti, 'MLDBM' , $hashfilecelexlistinverted,  O_RDONLY, 0666, $DB_BTREE);
    Dumper($db2->{DB});
    $db2->{DB}->Filter_Push('utf8');    

    $db2a = tie (%hcelexicsa, 'MLDBM' , $hashfilecelexics,  O_RDONLY, 0666, $DB_BTREE);
    Dumper($db2a->{DB});
    $db2a->{DB}->Filter_Push('utf8');

    $db2b = tie (%hcelexicstructsa, 'MLDBM' , $hashfilecelexicstruct,  O_RDONLY, 0666, $DB_BTREE);
    Dumper($db2b->{DB});
    $db2b->{DB}->Filter_Push('utf8');

    
    $db3 = tie (%houtput, 'MLDBM', $outputhashfile,  O_TRUNC|O_CREAT, 0666, $DB_BTREE);
    Dumper($db3->{DB});
    $db3->{DB}->Filter_Push('utf8');

    if ($zitlimit)
    {
	$dballo = tie (%hzallo, 'MLDBM', $hashfilecelexstemallomorphs,  O_RDONLY, 0666, $DB_BTREE);
	Dumper($dballo->{DB});
	$dballo->{DB}->Filter_Push('utf8');
    }

    if ($nlevenshtein)
    {
	$dbdiss = tie (%hzdiss, 'MLDBM', $hashfilecelexdissimallomorphs,  O_RDONLY, 0666, $DB_BTREE);
	Dumper($dbdiss->{DB});
	$dbdiss->{DB}->Filter_Push('utf8');

	$dbpos = tie (%hcelexposa, 'MLDBM', $hashfilecelexpos,  O_RDONLY, 0666, $DB_BTREE);
	Dumper($dbpos->{DB});
	$dbpos->{DB}->Filter_Push('utf8');
    }

    
    while(($orthform, $ref_acompounds) = each(%hinput))
    {

	$nit = 0;
	$zit = 0;
	@acompounds = @$ref_acompounds;
	@anewcompounds = ();
	print "in hash: $orthform @acompounds \n";
	$parenthesesbefore = "";
	$parenthesesafter = "";
	$linginfobefore = "";
	
	foreach $compound (@acompounds)
	{
	    print "compound: $compound\n";
	    @anewcompound = ();
	   
	    @aconstituents =  split /[|]/, $compound;
	    foreach $constituent (@aconstituents) 
	    {
		#print "1 anewcompound:\n";
		#print Dumper (@anewcompound);
		$flaglev = 0;
		print "constituent: $constituent\n";
		
		$constituentcopy = $constituent;
		$constituentcopy =~ /^(\(*)([^\)]+)(\)*)$/;
		$parenthesesbefore = $1;
		$parenthesesafter = $3;
		$constituentcopy = $2;
		$linginfobefore = "";

		if ($parenthesesbefore && $flaginfosintree) # do not analyse the linguistic information
		{
		    $constituentcopy =~ /^(.* )(.*)$/;
		    $linginfobefore = $1;
		    $constituentcopy = $2;
		  #  print "Parentheses: $parenthesesbefore $linginfobefore $constituentcopy\n";
		}

		if ($flagpos)
		{
		    $constituentcopy =~ /(.*)\_(.)$/;
		    $constituentcopy = $1;
		    $pos = $2;
		    print "Constituentcopy: $constituentcopy\n";
		}

		if (exists $hcelexlisti{$constituentcopy})
		{
		    $nit = 1;
		    $ref_index = $hcelexlisti{$constituentcopy};
		    $index = @$ref_index[0];
		    print "index: $index\n";
		   
		    $derivorcomp = $hcelexicsa{$index};
		    print "DC: $derivorcomp\n";

		    #check for conversion with stem allomorphy
		    
		    if ($zitlimit && exists $hzallo{$index})
		    {
			$zit = 1;
			print "SA in conversion $zit $constituentcopy\n";
			if ($zit >= $zitlimit)  # if the limit is reached just change the general limit
			{
			    $nit = $nitlimit;
			}
		    }
###
		    if ($nlevenshtein && exists $hzdiss{$index})
		    {
			# $zit = 1;
			print "Too dissimilar forms according to threshold: $constituentcopy\n Do not take $derivorcomp.\n";
			$derivorcomp = $constituentcopy;
			
			$nit = $nitlimit;
			$flaglev = "T";
		    }
		    
###		    
		    # build-in stop (though it is a heuristics)
		    if ($constituentcopy eq $derivorcomp)
		    {
			$nit = $nitlimit;
		    }

		    if ($flagpos) # get ICstruct and append to components
		    {
			if ($flaglev eq "T")
			{
			    $derivorcompstruct = $hcelexposa{$index}; # the pos of the part, do not analyse the structure
			    print "Index: $index , Structure of part: $derivorcompstruct of \n";
			}
			else
			{
			    $derivorcompstruct = $hcelexicstructsa{$index}; # the pos of the structure 
			}
			# print "ICstruct of DC: $derivorcompstruct\n";
			@derivorcompcopy = split /[|]/, $derivorcomp;
			@derivorcompstructcopy = split //, $derivorcompstruct;
			@derivorcompplusstruct = pairwise {$a . "\_" . $b} @derivorcompcopy, @derivorcompstructcopy;
			$derivorcomp = join ('|', @derivorcompplusstruct);
			print "New derivorcomp: $derivorcomp\n";
		    }
		    
		    if ($nit >= $nitlimit) # no deeper search
		    {
#			print "no deeper search\n";
			my @alist = ();
			push (@alist, $derivorcomp);

			if ($flaglev)
			{
			    @alist = map { "($_)" } @alist;
			}
			
			elsif ($flaginfosintree && $flagpos)
			{
			    $linginfo = "*" . $constituentcopy . "_" . $pos .  "*";
			    @alist = map { "($linginfo $_)" } @alist;
			}						
			elsif ($flaginfosintree)
			{
			    $linginfo = "*" . $constituentcopy . "*";
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
			
			if ($parenthesesbefore || $parenthesesafter) 
			{
			    my @alistcopy = ();
#			    print "Parentheses: $parenthesesbefore $constituentcopy $parenthesesafter\n";
			    foreach $member (@alist)
			    {
				$member = join("", $parenthesesbefore, $linginfobefore, $member, $parenthesesafter);
				push @alistcopy, $member;
			    }
			    @alist = @alistcopy;
			}		

			$parenthesesbefore = "";
			$parenthesesafter = "";
			$linginfobefore = "";
			push (@anewcompound, \@alist);
		    }
		    else # deeper analysis
		    {
			my @alist = ();
			push (@alist, $derivorcomp);
			
			$ref_structure = deep_addcelexsplits(\@alist, $nit, $zit, $nitlimit, $zitlimit, $nlevenshtein, $flaginfosintree, $flagpos);
			@alist = @{$ref_structure};
		#	print "deeper analysis\n";
			if ($flaginfosintree && $flagpos)
			{
			    $linginfo = "*" . $constituentcopy . "_" . $pos .  "*";
			    @alist = map { "($linginfo $_)" } @alist;
			}			
			elsif ($flaginfosintree)
			{
			    $linginfo = "*" . $constituentcopy . "*";
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
			
			if ($parenthesesbefore || $parenthesesafter) 
			{
			    my @alistcopy = ();
			#    print "Parentheses: $parenthesesbefore $constituentcopy\n";
			    foreach $member (@alist)
			    {
				$member = join("", $parenthesesbefore, $linginfobefore, $member, $parenthesesafter);
				push @alistcopy, $member;
			    }
			    @alist = @alistcopy;
			}		
			
			$parenthesesbefore = "";
			$parenthesesafter = "";
			$linginfobefore = "";
			push (@anewcompound, \@alist);
		    }
		}
		
		else # no entry in inverted index 
		{
		    push (@anewcompound, [$constituent]); # reference to array with constituent
		}
	    }
	    
	    @acartesianresult = mycartesian (@anewcompound);
#	    print "acartesianresult for analyses:\n";
#	    print Dumper (@acartesianresult);
	    @allsetstrings = ();

	    for $set (@acartesianresult)
	    {
		my @alist = @$set;
#		$setstring = join ('|', @$set);
		$setstring = join ('|', @alist);
		print "Set: $setstring\n";
		
		if (($flagparstyle) && ($#alist > 0)) #at least two elements  
		{
		    $setstring =  join ('',  map { if ($_ !~ /^\(.*\)/) {"($_)"} else {"$_"} } @alist);
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
    untie (%hcelexlisti);

    undef $db2a;
    untie (%hcelexicsa);

    undef $db2b;
    untie (%hcelexicstructsa);
    
    undef $db3;
    untie (%houtput);

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

sub deep_addcelexsplits{
    my ($ref_array, $nit, $zit, $nlimit, $zlimit, $lev, $flaginfosintrees, $flagpos) = @_;
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

    @aconstfromabove = @$ref_array;
    print "deep analysis of @aconstfromabove \n";
    @anewcomps = ();
    
    foreach $const (@aconstfromabove)
    {
	$currentn = $nit + 1;
	$currentz = $zit;
	@aconsts =  split /[|]/, $const;
	foreach $constofconst (@aconsts)
	{
	    $flaglev = 0;
	    print "constofconst: $constofconst\n";
	    
	    if ($flagpos)
	    {
		$constofconst =~ /(.*)\_(.)$/;
		$constofconst = $1;
		$pos = $2;
		#   print "constofconst: $constofconst\n";
	    }
	   
	    if (exists $hcelexlisti{$constofconst})

	    {
		$ref_indexc = $hcelexlisti{$constofconst};
		$indexc = @$ref_indexc[0];
		print "indexc: $indexc\n";
		
		$derivorcomp = $hcelexicsa{$indexc};

		if ($zlimit && exists $hzallo{$indexc})
		{
		    $currentz = $zit + 1;
		    print "Deep SA in conversion $currentz $constofconst $derivorcomp\n";
		    if ($currentz >= $zlimit)  # if the limit is reached just change the general limit
		    {
			$currentn = $nlimit;
		    }
		}
		print "lev: $lev\n";
		if ($lev && exists $hzdiss{$indexc})
		{
		    # $zit = 1;
		    print "Too dissimilar forms according to threshold: $constofconst\n Do not take $derivorcomp.";
		    $derivorcomp = $constofconst;
		    $currentn = $nlimit;
		    $flaglev = "T";
		}
		    		
		# build-in stop (though it is a heuristics)
		if ($constofconst eq $derivorcomp)
		{
		    $currentn = $nlimit;
		}

		if ($flagpos) # get ICstruct and append to components
		{
		    if ($flaglev eq "T")
		    {
			$derivorcompstruct = $hcelexposa{$indexc}; # the pos of the part, do not analyse the structure
			print "$index $derivorcompstruct of part\n";
		    }
		    else
		    {
			$derivorcompstruct = $hcelexicstructsa{$indexc}; # the pos of the structure 
		    }
		    #		    $derivorcompstruct = $hcelexicstructsa{$indexc};
		    # print "ICstruct of DC: $derivorcompstruct\n";
		    @derivorcompcopy = split /[|]/, $derivorcomp;
		    @derivorcompstructcopy = split //, $derivorcompstruct;
		    @derivorcompplusstruct = pairwise {$a . "\_" . $b} @derivorcompcopy, @derivorcompstructcopy;
		    $derivorcomp = join ('|', @derivorcompplusstruct);
		    print "New derivorcomp: $derivorcomp\n";
		}
		
		if ($currentz == $zlimit) # no deeper search and treat the last entry like a monomorphemic form
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

		elsif ($currentn == $nlimit) # no deeper search
		{
		    my @alist = ();
		    push (@alist, $derivorcomp);
		    
		    if ($flaglev)
		    {
			@alist = map { "($_)" } @alist;
		    }
			
		    
		    elsif ($flaginfosintree && $flagpos)
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
		else # deeper analysis
		{
		    my @alist = ();
		    push (@alist, $derivorcomp);
		    
		    $ref_structure = deep_addcelexsplits(\@alist, $currentn, $currentz, $nlimit, $zlimit, $lev, $flaginfosintree, $flagpos);
		    
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
	    else # not in hcelexlisti (i.e. monomorphemic in CELEX)
	    {
		if ($flagpos)
		{
		    $constofconst .= "_" . $pos;
		}
		    
		push (@anewcomp, [$constofconst]); # reference to array with constituent	
	    }
	}
#	print "anewcomp: @anewcomp\n";
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
#	print "result of deep analysis: @anewcomps\n";
    return(\@anewcomps);
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

