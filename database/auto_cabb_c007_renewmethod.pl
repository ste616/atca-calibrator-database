#!/usr/bin/perl

use Astro::Time;
use POSIX;
use CalDBkaputar;
use CalDB;

use strict;
# Script for manual automatic (!) reduction of CABB C007 data.

my @months = ( 'JAN', 'FEB', 'MAR', 'APR',
	       'MAY', 'JUN', 'JUL', 'AUG',
	       'SEP', 'OCT', 'NOV', 'DEC' );

# go through the command line arguments
my %arguments;
# some defaults
$arguments{'refant'}=2;
$arguments{'scaleonly'}=0;
$arguments{'breaks'}='';
$arguments{'fit-order'}=1;
$arguments{'qusolve'}=0;
$arguments{'noshift'}=0;
$arguments{'nfbin'}=2;
$arguments{'polsolve'}=0;
$arguments{'mfflux'}='';
$arguments{'gpcal-interval'}=0.1;
$arguments{'mfcal-edge'} = 20;
$arguments{'elevation-overlap'} = 0;
$arguments{'xyvary'} = 1;
for (my $i=0;$i<=$#ARGV;$i++){
    # strip off any trailing forward slashes
    $ARGV[$i]=~s/\/$//;
    if (($ARGV[$i] eq "--fluxcal")||
	($ARGV[$i] eq "--bandpasscal")){
	my $specified=$ARGV[$i];
	$specified=~s/^\-\-(.*)$/$1/;
	$i++;
	$arguments{$specified}=$ARGV[$i];
    } elsif ($ARGV[$i] eq "--noflag"){
	# user doesn't want us to flag a particular dataset
	$i++;
	push @{$arguments{'noflag'}},$ARGV[$i];
    } elsif ($ARGV[$i] eq "--justscale"){
	# user just wants to get straight to the scaling
	$arguments{'scaleonly'}=1;
    } elsif ($ARGV[$i] eq "--noflagging"){
	# user doesn't want autoflagging at all
	$arguments{'noflagging'}=1;
    } elsif ($ARGV[$i] eq "--freq"){
	# user only wants to reduce one frequency
	$i++;
	$arguments{'onlyfreq'}=$ARGV[$i];
    } elsif ($ARGV[$i] eq "--reference"){
	# user wants to use a different reference antenna
	$i++;
	$arguments{'refant'}=$ARGV[$i];
    } elsif ($ARGV[$i] eq "--breaks") {
	# user wants to insert a gpbreak time
	$i++;
	$arguments{'breaks'}=$ARGV[$i];
    } elsif ($ARGV[$i] eq "--fit-order") {
	# User is telling us the order of the fit to use.
	$i++;
	$arguments{'fit-order'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--qusolve") {
	# Allow us to solve for QU.
	$arguments{'qusolve'} = 1;
    } elsif ($ARGV[$i] eq "--source") {
	# Only reduce a single source.
	$i++;
	$arguments{'source'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--no-shift") {
	# Don't allow the script to shift the source position.
	$arguments{'noshift'} = 1;
    } elsif ($ARGV[$i] eq "--nfbin") {
	# Change the number of bins used in gpcal.
	$i++;
	$arguments{'nfbin'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--solve-pols") {
	# Solve for pols independently on each calibrator.
	$arguments{'polsolve'} = 1;
    } elsif ($ARGV[$i] eq "--mfflux") {
	# Specify the bandpass/flux calibrator's flux model.
	$i++;
	$arguments{'mfflux'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--gpcal-interval") {
    	# Set the interval to use for gpcal.
	$i++;
	$arguments{'gpcal-interval'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--mfcal-edge") {
	# Change the edge parameter for mfcal.
	$i++;
	$arguments{'mfcal-edge'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--elevation-overlap") {
	# User wants to bootstrap within some elevation tolerance.
	$i++;
	$arguments{'elevation-overlap'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--no-xyvary") {
	# Don't allow xyvary in the gpcal stage for non-flux calibrators.
	$i++;
	$arguments{'xyvary'} = 0;
    }
}

# has a flux calibrator been specified?
if (!$arguments{'fluxcal'}){
    # no, so we die
    die "!! no flux calibrator specified\n";
}
# has a bandpass calibrator been specified?
if (!$arguments{'bandpasscal'}){
    # no, so we use the flux calibrator
    $arguments{'bandpasscal'}=$arguments{'fluxcal'};
}

# build a list of the files to reduce
my @reduce_list;
my @flux_list;
my @bandpass_list;
open(LS,"-|")||exec "ls";
while(<LS>){
    chomp;
    my $test=$_;
    if (!-d $test){
	# Miriad datasets are directories
	next;
    }
    if ($test=~/$arguments{'bandpasscal'}/){
	push @bandpass_list,$test;
    }
    if ($test=~/$arguments{'fluxcal'}/){
	# don't reduce the flux calibrator
	push @flux_list,$test;
	next;
    }
    if ($test=~/^.*\.\d+$/){
	if ($arguments{'onlyfreq'}){
	    # needs to also fit a frequency specification
	    if ($test!~/\.$arguments{'onlyfreq'}$/){
		next;
	    }
	}
	# fits the mould sourcename.frequency
	# Does it match the source if we've been given one?
	if (($arguments{'source'} && $test=~/$arguments{'source'}/) ||
	    $test =~ /$arguments{'bandpasscal'}/ ||
	    $test =~ /$arguments{'fluxcal'}/ ||
	    !$arguments{'source'}) {
	    push @reduce_list,$test;
	    print "++ adding $test to reduction list\n";
	}
    }
}
close(LS);

if ($arguments{'scaleonly'}==0){

    my $bpround = 0;
    my $bpdone = 0;
    my $bpflux;
    while ($bpdone == 0) {
# start by getting the correct bandpass solutions
	for (my $i=0;$i<=$#bandpass_list;$i++){
	    # delete any current calibration solutions
	    &delete_calibration($bandpass_list[$i]);
	    if ($bpround == 1 || $arguments{'mfflux'} ne '') {
		if ($arguments{'mfflux'} ne '') {
		    $bpflux = $arguments{'mfflux'};
		} else {
		    $arguments{'mfflux'} = $bpflux;
		    for (my $ii = 0; $ii <= $#bandpass_list; $ii++) {
			$flux_list[$ii] = $bandpass_list[$ii];
		    }
		}
		&calibrate($bandpass_list[$i],"bandpass",$arguments{'breaks'}, $bpflux);
	    } else {
		&calibrate($bandpass_list[$i],"bandpass",$arguments{'breaks'});
		my $rc=&autoflag($bandpass_list[$i]);
		if ($rc==0){
		    &calibrate($bandpass_list[$i],"bandpass",$arguments{'breaks'});
		}
	    }
	}
	
# copy the bandpass solutions to the flux calibrator
	for (my $j=0;$j<=$#bandpass_list;$j++){
	    my $this_freq=$bandpass_list[$j];
	    $this_freq=~s/^.*\.(\d+)$/$1/;
	    for (my $i=0;$i<=$#flux_list;$i++){
		if (($flux_list[$i]=~/\.$this_freq$/)&&
		    ($flux_list[$i] ne $bandpass_list[$j])){
		    &delete_calibration($flux_list[$i]);
		    &copy_calibration($bandpass_list[$j],$flux_list[$i]);
		}
	    }
	}
	
# calibrate and flag the flux calibrators
	for (my $i=0;$i<=$#flux_list;$i++){
	    my $this_freq=$flux_list[$i];
	    $this_freq=~s/^.*\.(\d+)$/$1/;
	    my $rc=&calibrate($flux_list[$i],"gains",$arguments{'breaks'});
	    if ($rc==0){
		my $trc = 0;
		for (my $j=0; $j<=$#bandpass_list; $j++) {
		    if (($bandpass_list[$i] =~ /\.$this_freq$/) &&
			($flux_list[$i] ne $bandpass_list[$j])) {
			$trc=&autoflag($flux_list[$i]);
		    }
		}
		if ($trc==0){
		    &calibrate($flux_list[$i],"gains",$arguments{'breaks'});
		}
	    }
	}
	
# fix the bandpass calibrators
	for (my $i=0;$i<=$#bandpass_list;$i++){
	    my $this_freq=$bandpass_list[$i];
	    $this_freq=~s/^.*\.(\d+)$/$1/;
	    for (my $j=0;$j<=$#flux_list;$j++){
		if (($flux_list[$j]=~/\.$this_freq$/)&&
		    (($flux_list[$j] ne $bandpass_list[$i]) ||
		     $arguments{'mfflux'} ne '')){
		    &scale_fluxes($bandpass_list[$i],$flux_list[$j],
				  $arguments{'mfflux'});
#		} elsif ($flux_list[$j]=~/\.$this_freq$/) {
#		    # just do the spectral index correction in
#		    # case it failed first time
#		    my $ip = &is_planet($bandpass_list[$i]);
#		    &flux_scale($bandpass_list[$i],$flux_list[$j],$ip);
		}
	    }
	}

# do we continue with the bandpass calibration?
	if ($bandpass_list[0] =~ /^1934-638/ || $arguments{'mfflux'} ne '') {
	    # no, since the bandpass solution should now be correct
	    $bpdone = 1;
	} elsif ($bpround == 1) {
	    # no, since we should have already done the correction
	    $bpdone = 1;
	} else {
	    # yes, but first we measure the actual global fit to the
	    # current bandpass calibrator
	    $bpflux = &measure_fit(\@bandpass_list);
	    $bpround++;
	}
    }

# copy the correct solution to all the reduction sources
    for (my $i=0;$i<=$#reduce_list;$i++){
	my $this_freq=$reduce_list[$i];
	$this_freq=~s/^.*\.(\d+)$/$1/;
	# Check for an offset calibrator.
	my %set_info = &get_set_info($reduce_list[$i]);
	my %db_pos = &get_database_position($reduce_list[$i]);
	my $dra = abs(str2deg($set_info{'source'}->{'ra'}, 'H') -
		      str2deg($db_pos{'ra'}, 'H'));
	my $ddec = abs(str2deg($set_info{'source'}->{'dec'}, 'D') -
		       str2deg($db_pos{'dec'}, 'D'));
#	if (($set_info{'source'}->{'ra'} ne $db_pos{'ra'}) ||
#	    ($set_info{'source'}->{'dec'} ne $db_pos{'dec'})) {
	if ($dra > (1 / 3600) || $ddec > (1 / 3600)) {
	    # We need to shift this set.
	    &shift_source($reduce_list[$i], $db_pos{'ra'}, $db_pos{'dec'});
	}
	for (my $j=0;$j<=$#bandpass_list;$j++){
	    if (($bandpass_list[$j]=~/\.$this_freq$/)&&
		($bandpass_list[$j] ne $reduce_list[$i])){
		&delete_calibration($reduce_list[$i]);
		&copy_calibration($bandpass_list[$j],$reduce_list[$i]);
	    }
	}
    }
    
# calibrate and flag the reduction list
    for (my $i=0;$i<=$#reduce_list;$i++){
	if ($reduce_list[$i] =~ /^$arguments{'bandpasscal'}/) {
	    next;
	}
	my $rc=&calibrate($reduce_list[$i],"gains",$arguments{'breaks'});
	if ($rc==0){
	    my $trc=&autoflag($reduce_list[$i]);
	    if ($trc==0){
		&calibrate($reduce_list[$i],"gains",$arguments{'breaks'});
	    }
	}
    }
}

# now scale the reduction list to the flux calibrators
for (my $i=0;$i<=$#reduce_list;$i++){
    my $this_freq=$reduce_list[$i];
    $this_freq=~s/^.*\.(\d+)$/$1/;
    for (my $j=0;$j<=$#bandpass_list;$j++){
	if (($bandpass_list[$j]=~/\.$this_freq$/)&&
	    ($bandpass_list[$j] ne $reduce_list[$i])){
#	    &scale_fluxes($reduce_list[$i],$flux_list[$j]);
	    &bootstrap_scale($bandpass_list[$j],$reduce_list[$i]);
	}
    }
}


sub is_planet {
    my ($dataset)=@_;

    # check if the dataset is a planet
    my @planets=("mercury","venus","mars","jupiter","saturn","uranus",
		 "neptune");
    my $this_set=$dataset;
    $this_set=~tr/[A-Z]/[a-z]/;
    for (my $i=0;$i<=$#planets;$i++){
	if ($this_set=~/$planets[$i]/){
	    return 1;
	}
    }

    return 0;
}
    
sub scale_fluxes {
    my ($reduce_dataset,$flux_dataset,$mfflux)=@_;
    
    # check if either dataset is a planet
    my $reduce_is_planet=&is_planet($reduce_dataset);
    my $flux_is_planet=&is_planet($flux_dataset);

    # get both datasets to have the same gains table
    if ($mfflux ne '') {
	&flux_scale($flux_dataset,$reduce_dataset,$flux_is_planet,
		    $mfflux);
	return;
    } elsif ($flux_is_planet && !$reduce_is_planet){
	&copy_calibration($reduce_dataset,$flux_dataset);
    } elsif (!$flux_is_planet && $reduce_is_planet){
	&copy_calibration($flux_dataset,$reduce_dataset);
    } elsif (!$flux_is_planet && !$reduce_is_planet){
	&bootstrap_scale($flux_dataset,$reduce_dataset);
	return;
    } # otherwise both are planets, and they both already have the
      # calibration solution from the bandpass calibrator

    # now do the flux scaling and bandpass slope correction
    &flux_scale($flux_dataset,$reduce_dataset,$flux_is_planet,$mfflux);

}

sub flux_scale {
    my ($scale_source,$scale_destination,$scale_is_planet,$mfflux)=@_;

    my $source_scale=$scale_source;
    $source_scale=~s/^(.*)\.(\d+)$/$1/;
    my $scale_command;
    if ($scale_source ne $scale_destination){
	$scale_command="mfboot vis=".$scale_destination.
	    ",".$scale_source." \"select=source(".$source_scale.")\"";
    } else {
	$scale_command="mfboot vis=".$scale_destination.
	    " \"select=source(".$source_scale.")\"";
    }
    if ($scale_is_planet==0){
	# need to add mode=vector to prevent a scaling bug
	$scale_command.=" mode=vector";
    }
    if ($mfflux ne '') {
	$scale_command .= " flux=".$mfflux;
    }
    &execute_miriad($scale_command);
}

sub determine_elevation_ranges {
    my $source = shift;

    my %eldata = (
	'elevation' => {
	    'min' => 90, 'max' => 12
	},
	'time' => {
	    'min' => -1, 'max' => -1
	},
	'scans' => []
	);
    
    my $uvplt_command = "uvplt vis=".$source.
	" axis=time,el options=nobase,nopass,nopol,nocal,log ".
	" device=/null stokes=i";
    open(U, "-|") || exec $uvplt_command;
    my $csi = -1;
    while(<U>) {
	chomp;
	my @els = split(/\s+/);
	if ($#els == 1 && $els[1] >= 12 && $els[1] <= 90) {
	    if ($csi == -1 || $els[0] >= ($eldata{'scans'}->[$csi]->{'end_time'} + 30)) {
		# Add a new scan.
		push @{$eldata{'scans'}}, {
		    'start_time' => $els[0],
		    'end_time' => $els[0],
		    'min_elevation' => $els[1],
		    'max_elevation' => $els[1]
		};
		$csi = $#{$eldata{'scans'}};
	    } else {
		# Keep building on the current scan.
		$eldata{'scans'}->[$csi]->{'end_time'} = $els[0];
		$eldata{'scans'}->[$csi]->{'min_elevation'} = ($els[1] < $eldata{'scans'}->[$csi]->{'min_elevation'}) ?
		    $els[1] : $eldata{'scans'}->[$csi]->{'min_elevation'};
		$eldata{'scans'}->[$csi]->{'max_elevation'} = ($els[1] > $eldata{'scans'}->[$csi]->{'max_elevation'}) ?
		    $els[1] : $eldata{'scans'}->[$csi]->{'max_elevation'};
	    }
	    $eldata{'elevation'}->{'min'} = ($els[1] < $eldata{'elevation'}->{'min'}) ? 
		$els[1] : $eldata{'elevation'}->{'min'};
	    $eldata{'elevation'}->{'max'} = ($els[1] > $eldata{'elevation'}->{'max'}) ? 
		$els[1] : $eldata{'elevation'}->{'max'};
	    if ($eldata{'time'}->{'min'} == -1) {
		$eldata{'time'}->{'min'} = $els[0];
		$eldata{'time'}->{'max'} = $els[0];
	    } else {
		$eldata{'time'}->{'min'} = ($els[0] < $eldata{'time'}->{'min'}) ?
		    $els[0] : $eldata{'time'}->{'min'};
		$eldata{'time'}->{'max'} = ($els[0] > $eldata{'time'}->{'max'}) ?
		    $els[0] : $eldata{'time'}->{'max'};
	    }
	}
    }
    close(U);

    # Output some debugging information.
    print "DD Found ".($#{$eldata{'scans'}} + 1)." scans in the dataset ".
	$source."\n";
    for (my $i = 0; $i <= $#{$eldata{'scans'}}; $i++) {
	print "DD Scan ".($i + 1).": Time ".
	    turn2str(($eldata{'scans'}->[$i]->{'start_time'} / 86400), 'H', 0)." -> ".
	    turn2str(($eldata{'scans'}->[$i]->{'end_time'} / 86400), 'H', 0).", el ".
	    $eldata{'scans'}->[$i]->{'min_elevation'}." -> ".
	    $eldata{'scans'}->[$i]->{'max_elevation'}."\n";
    }
    
    return %eldata;
}

sub bootstrap_scale {
    my ($scale_source,$scale_destination)=@_;

    my $tselect = "";
    if ($arguments{'elevation-overlap'} > 0) {
	# Get the elevation ranges of the flux calibrator and destination calibrator.
	my %source_ranges = &determine_elevation_ranges($scale_source);
	my %destination_ranges = &determine_elevation_ranges($scale_destination);

	# Find the scans that fall within the overlap range with the flux calibrator.
	my @usable_scans;
	for (my $i = 0; $i <= $#{$destination_ranges{'scans'}}; $i++) {
#	    print "DD Comparing flux calibration to calibrator scan ".($i + 1)."\n";
	    # First check for any overlap.
	    if (($destination_ranges{'scans'}->[$i]->{'min_elevation'} >
		 $source_ranges{'elevation'}->{'min'} &&
		 $destination_ranges{'scans'}->[$i]->{'min_elevation'} <
		 $source_ranges{'elevation'}->{'max'}) ||
		($destination_ranges{'scans'}->[$i]->{'max_elevation'} >
		 $source_ranges{'elevation'}->{'min'} &&
		 $destination_ranges{'scans'}->[$i]->{'max_elevation'} <
		 $source_ranges{'elevation'}->{'max'}) ||
		($destination_ranges{'scans'}->[$i]->{'min'} <
		 $source_ranges{'elevation'}->{'min'} &&
		 $destination_ranges{'scans'}->[$i]->{'max'} >
		 $source_ranges{'elevation'}->{'max'})) {
		# An overlap exists.
#		print "DD Overlap found, this is a usable scan.\n";
		push @usable_scans, { 'index' => $i,
				      'distance' => 0 };
	    } else {
		my $d = 2 * $arguments{'elevation-overlap'};
		# Determine the closest distance between the scans.
		if ($destination_ranges{'scans'}->[$i]->{'min_elevation'} >
		    $source_ranges{'elevation'}->{'max'}) {
		    $d = $destination_ranges{'scans'}->[$i]->{'min_elevation'} -
			$source_ranges{'elevation'}->{'max'};
		} else {
		    $d = $source_ranges{'elevation'}->{'min'} -
			$destination_ranges{'scans'}->[$i]->{'max_elevation'};
		}
#		print "DD Minimum distance between scans is ".$d." degrees.\n";
		if ($d < 0) {
		    # Not supposed to happen!
		    print "WW Found a negative elevation distance when we shouldn't have!\n";
		} else {
		    if ($d < $arguments{'elevation-overlap'}) {
#			print "DD This is a usable scan.\n";
			push @usable_scans, { 'index' => $i,
					      'distance' => $d };
		    }
		}
	    }
	}

	# Make a select command.
	if ($#usable_scans >= 0) {
	    # Some time range is usable.
	    my ($tmin, $tmax);
	    if ($#usable_scans == 0) {
		# Only one time range is usable, easy.
		$tmin = $destination_ranges{'scans'}->[$usable_scans[0]->{'index'}]->{'start_time'};
		$tmax = $destination_ranges{'scans'}->[$usable_scans[0]->{'index'}]->{'end_time'};
	    } else {
		# Find the time range closest to the elevation range of the
		# flux calibrator.
		my @s_usable_scans = sort { $a->{'distance'} <=> $b->{'distance'} } @usable_scans;
		$tmin = $destination_ranges{'scans'}->[$s_usable_scans[0]->{'index'}]->{'start_time'};
		$tmax = $destination_ranges{'scans'}->[$s_usable_scans[0]->{'index'}]->{'end_time'};
	    }
	    
	    $tmin = $tmin % 86400;
	    $tmax = $tmax % 86400;
	    $tmin /= 86400;
	    $tmax /= 86400;
	    $tselect = sprintf "\"select=time(%s,%s)\"", turn2str($tmin, "H", 0),
	    turn2str($tmax, "H", 0);
	} else {
	    # Otherwise there is no good overlap region, but just do it anyway.
	    print "WW No overlap elevation range found!\n";
	}
    }

    my $scale_command="gpboot vis=".$scale_destination.
	" cal=".$scale_source." ".$tselect;
    &execute_miriad($scale_command);
}

sub copy_calibration {
    my ($in_dataset,$out_dataset)=@_;

    my $tolerance_command="puthd in=".$in_dataset."/interval ".
	"value=2";
    &execute_miriad($tolerance_command);

    my $copy_command="gpcopy vis=".$in_dataset." out=".$out_dataset;
    &execute_miriad($copy_command);

}

sub measure_fit {
    my $bandpass_sets = shift;
    
    my $command = "uvfmeas vis=";
    for (my $i=0; $i<=$#{$bandpass_sets}; $i++) {
	if ($i > 0) {
	    $command .= ",";
	}
	$command .= $bandpass_sets->[$i];
    }
    $command .= " stokes=i options=plotvec,log,mfflux device=/null".
	" order=".$arguments{'fit-order'};
    
    my @uvf_output = &execute_miriad($command);
    my $bpflux;
    for (my $i=0; $i<=$#uvf_output; $i++) {
	if ($uvf_output[$i] =~ /^MFCAL flux\=\s*(.*)$/) {
	    $bpflux = $1;
	    $bpflux =~ s/\s//g;
	}
    }

    return $bpflux;
}

sub calibrate {
    my $dataset = shift;
    my $mode = shift;
    my $breaks = shift;
    my $bpflux = shift;
    my $dofit = defined $bpflux;

    # check that we're not dealing with a planet in this routine
    if (&is_planet($dataset)){
	print "WW will not attempt calibration on planet $dataset\n";
	return -1;
    }

    my $options;
    my $command;
    my $interval=0.1;
    my $refant=$arguments{'refant'};
    my $c = 1;
    while ($c > 0) {
	if ($mode eq "bandpass" && $c == 1){
	    $command="mfcal edge=".$arguments{'mfcal-edge'};
	    $options="";
	    if ($dofit) {
		$command .= " flux=".$bpflux;
	    }
	    if ($dataset!~/1934-638/) {
		$c = 0;
	    } else {
		$c++;
	    }
	    $command .= " interval=".$interval;
	} elsif ($mode eq "gains" || $c > 1){
	    $command="gpcal nfbin=".$arguments{'nfbin'};
	    if ($arguments{'xyvary'} == 1) {
	    	$options="xyvary";
	    } else {
	        $options="linear";
	    }
	    if ($dataset!~/1934-638/) {
		if ($arguments{'qusolve'} == 1) {
		    $options.=",qusolve";
		}
		if ($arguments{'polsolve'} == 0) {
		    $options.=",nopol";
		}
	    }
	    $c = 0;
	    $command .= " interval=".$arguments{'gpcal-interval'};
	}
	my $calibrate_command=$command." refant=".$refant.
	    " vis=".$dataset;
	if ($options ne ""){
	    $calibrate_command.=" options=".$options;
	}
	&execute_miriad($calibrate_command);
    }

    # Add in any gpbreaks if required.
    if ($breaks ne '') {
	my $break_command = "gpbreak vis=".$dataset." break=".$breaks;
	&execute_miriad($break_command);
    }

    return 0;
}

sub autoflag {
    my ($dataset)=@_;

    # check if autoflagging is permitted
    if ($arguments{'noflagging'}){
	return -1;
    }

    # check if the dataset is on the no-flag list
    my @noflags;
    if ($arguments{'noflag'}){
	@noflags=@{$arguments{'noflag'}};
    }
    for (my $i=0;$i<=$#noflags;$i++){
	if ($dataset=~/$noflags[$i]/){
	    print "WW not flagging dataset $dataset\n";
	    return -1;
	}
    }
    
    my @flag_stokes=("xx,yy","yy,xx");
#    my $autoflag_command="mirflag vis=".$dataset.
#	" options=amp,medsed,short";
    my $autoflag_command="pgflag vis=".$dataset.
	" \"command=<b\" device=/null options=nodisp";
    for (my $i=0;$i<=$#flag_stokes;$i++){
	&execute_miriad($autoflag_command." stokes=".
			$flag_stokes[$i]);
    }
    return 0;
}

sub delete_calibration {
    my ($this_dataset)=@_;
    
    $this_dataset=~s/\/$//;
    my @delete_items=( "gains","bandpass","leakage",
		       "gainsf", "leakagef" );
    for (my $i=0;$i<=$#delete_items;$i++){
	my $delhd_command="delhd in=".$this_dataset."/".
	    $delete_items[$i];
	&execute_miriad($delhd_command);
    }
}

sub execute_miriad {
    my ($miriad_command)=@_;

    my @miriad_output;
    print "EE executing $miriad_command\n";
    open(MIRIAD,"-|")||exec $miriad_command." 2>&1";
    while(<MIRIAD>){
	chomp;
	my $line=$_;
	push @miriad_output,$line;
	print "MM $line\n";
    }
    close(MIRIAD);

    return @miriad_output;
}

sub shift_source {
    my $setname = shift;
    my $newra = shift;
    my $newdec = shift;
    if ($arguments{'noshift'} == 1) {
	return;
    }
    if ($newra eq '' || $newdec eq '') {
	return;
    }

    print "MM Shifting set ".$setname." to RA,Dec=".$newra.",".
	$newdec."\n";

    my $cmd = "uvedit vis=".$setname." out=".$setname.".uvedit";
    $newra =~ s/\:/\,/g;
    $newdec =~ s/\:/\,/g;
    $cmd .= " ra=".$newra." dec=".$newdec;
    &execute_miriad($cmd);

    # Rename the sets.
    if (!-d "originals") {
	system "mkdir originals";
    }
    system "mv ".$setname." originals/".$setname.".orig";
    system "mv ".$setname.".uvedit ".$setname;

    return;
}

sub get_set_info {
    my $setname = shift;

    my $cmd = "uvindex vis=".$setname;
    my @cout = &execute_miriad($cmd);

    my %set_info = (
	'mjd' => { 'start' => 0, 'end' => 0, 'integration' => 0 },
	'source' => { 'name' => "", 'ra' => "", 'dec' => "" },
	'config' => { 'nchan' => 0, 'sfreq' => 0, 'dfreq' => 0 }
    );
    my $d = 0;
    for (my $i=0; $i<=$#cout; $i++) {
	my @els = split(/\s+/, $cout[$i]);
	my $t = &parse_miriad_time($els[0]);
	if ($t) {
	    if (!$set_info{'mjd'}->{'start'}) {
		$set_info{'mjd'}->{'start'} = $t;
	    } else {
		$set_info{'mjd'}->{'end'} = $t;
	    }
	} elsif ($cout[$i] =~ /Total observing time is/) {
	    $set_info{'mjd'}->{'integration'} = $els[4] / 24;
	} elsif ($els[1] eq "Source" &&
		 $els[2] eq "CalCode") {
	    $d = 1;
	} elsif ($d == 1) {
	    $set_info{'source'}->{'name'} = $els[0];
	    $set_info{'source'}->{'ra'} = $els[2];
	    $set_info{'source'}->{'dec'} = $els[3];
	    $d = 0;
	} elsif ($els[1] eq "Channels" &&
		 $els[2] eq "Freq(chan=1)") {
	    $d = 2;
	} elsif ($d == 2) {
	    $set_info{'config'}->{'nchan'} = $els[1];
	    $set_info{'config'}->{'sfreq'} = $els[2];
	    $set_info{'config'}->{'dfreq'} = $els[3];
	    $d = 0;
	}
    }

    return %set_info;
}

sub get_database_position {
    my $source = shift;
    $source =~ s/^([^\.]*)\..*$/$1/;
    
    my $cal_iterator = CalDB::Calibrator->search(
	'name' => $source
	);
    my $cal = $cal_iterator->next;

    my %rv = ( 'ra' => '', 'dec' => '' );

    if ($cal) {
	$rv{'ra'} = $cal->rightascension;
	$rv{'dec'} = $cal->declination;
    }
    return %rv;
}

sub parse_miriad_time {
    my $mirtime = shift;

    if ($mirtime =~ /^(..)(...)(..)\:(..)\:(..)\:(....)$/) {
	my $mjd;
	if ($1 < 30) {
	    $mjd = cal2mjd($3, &arrn(\@months, $2) + 1, 2000 + $1,
			   &hms2time($4, $5, $6));
	} else {
	    $mjd = cal2mjd($3, &arrn(\@months, $2) + 1, 1900 + $1,
			   &hms2time($4, $5, $6));
	}
	return $mjd;
    } else {
	return 0;
    }
}

sub arrn {
    my $a = shift;
    my $b = shift;

    for (my $i=0; $i<=$#{$a}; $i++) {
	if ($a->[$i] eq $b) {
	    return $i;
	}
    }
    return -1;
}

sub minarr {
    my @arr = @_;

    my $minv = $arr[0];
    my $mini = 0;
    for (my $i = 1; $i <= $#arr; $i++) {
	if ($arr[$i] < $minv) {
	    $minv = $arr[$i];
	    $mini = $i;
	}
    }

    return ($minv, $mini);
}
