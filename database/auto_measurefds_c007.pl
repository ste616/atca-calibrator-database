#!/usr/bin/perl

use Astro::Time;
use Data::Dumper;
use CalDBkaputar;
use CalDB;
use POSIX;
use strict;
# Script to measure flux densities for C007 project. Does not
# actually measure flux densities, but rather uses uvfmeas to
# fit a model to each source.

# Some variables for later use.
my %station_positions;
my @configuration_strings;
my @months = ( 'JAN', 'FEB', 'MAR', 'APR',
	       'MAY', 'JUN', 'JUL', 'AUG',
	       'SEP', 'OCT', 'NOV', 'DEC' );

# Go through the command line arguments.
my %arguments;
# Some defaults.
$arguments{'fit-order'} = 1;
$arguments{'update-db'} = 1;
$arguments{'only-source'} = '';
$arguments{'measure-fluxes'} = 1;
$arguments{'same-epoch'} = -1;
$arguments{'remeasure-epoch'} = -1;
$arguments{'update-changelog'} = 1;
$arguments{'public'} = 1;
$arguments{'keep-plots'} = 0;
$arguments{'self-calibrated'} = 1;
for (my $i=0; $i<=$#ARGV; $i++) {
    if ($ARGV[$i] eq "--fit-order") {
	# The order of the fit used in uvfmeas.
	$i++;
	$arguments{'fit-order'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--max-fit-order") {
	# Don't allow a higher fit order than this.
	$i++;
	$arguments{'max-fit-order'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--no-dbupdate") {
	# Don't update the calibrator database.
	$arguments{'update-db'} = 0;
    } elsif ($ARGV[$i] eq "--source") {
	# Only look at a single source (useful for debugging).
	$i++;
	$arguments{'only-source'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--no-fluxes") {
	# Don't measure flux densities (useful for debugging).
	$arguments{'measure-fluxes'} = 0;
    } elsif ($ARGV[$i] eq "--same-epoch") {
	# This is probably a different frequency but the same date
	# as a previously entered epoch.
	$i++;
	$arguments{'same-epoch'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--remeasure") {
	# We want to remeasure the flux densities for this
	# epoch.
	$i++;
	$arguments{'remeasure-epoch'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--reason") {
	# The user is giving a reason why something was done.
	$i++;
	$arguments{'reason'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--no-update-changelog") {
	# The user doesn't want us to update the database's
	# change log.
	$arguments{'update-changelog'} = 0;
    } elsif ($ARGV[$i] eq "--no-public") {
	# The user doesn't want us to make this data public.
	$arguments{'public'} = 0;
    } elsif ($ARGV[$i] eq "--keep-plots") {
	# The user wants to keep the plots from uvfmeas.
	$arguments{'keep-plots'} = 1;
    } elsif ($ARGV[$i] eq "--not-self-calibrated") {
	# Label these measurements as not self-calibrated.
	$arguments{'self-calibrated'} = 0;
    }
}

# Make a list of all the sources.
opendir my ($dh), "." or die "Unable to access current directory: $!";
my @sets = readdir $dh;
closedir $dh;

for (my $i=0; $i<=$#sets; $i++) {
    if (!-d $sets[$i] ||
	!-e $sets[$i]."/visdata") {
	splice @sets, $i, 1;
	$i--;
    } else {
#	print $sets[$i]."\n";
    }
}

my %epoch = (
    'mjd' => { 'start' => 0, 'end' => 0 },
    'project_codes' => []
    );
my %sources;

# Get information about each set.
my $eset = 0;
for (my $i=0; $i<=$#sets; $i++) {
    if ($arguments{'only-source'} eq '' ||
	$sets[$i] =~ /$arguments{'only-source'}/) {

	my %set_info = &get_set_info($sets[$i]);

	if ($eset == 0) {
	    $epoch{'array'} = &determine_array($sets[$i]);
	    $epoch{'mjd'}->{'start'} = $set_info{'mjd'}->{'start'};
	    $epoch{'mjd'}->{'end'} = $set_info{'mjd'}->{'end'};
	    $eset = 1;
	} else {
	    $epoch{'mjd'}->{'start'} = ($epoch{'mjd'}->{'start'} < $set_info{'mjd'}->{'start'}) ?
		$epoch{'mjd'}->{'start'} : $set_info{'mjd'}->{'start'};
	    $epoch{'mjd'}->{'end'} = ($epoch{'mjd'}->{'end'} > $set_info{'mjd'}->{'end'}) ?
		$epoch{'mjd'}->{'end'} : $set_info{'mjd'}->{'end'};
	}
	push @{$epoch{'project_codes'}}, &get_project_code($sets[$i]);
	$epoch{'project_code'} = &project_mode($epoch{'project_codes'});

	my %closure_phase = &measure_closure_phase($sets[$i]);
	if (!defined $sources{$set_info{'source'}->{'name'}}) {
	    $sources{$set_info{'source'}->{'name'}} = {
		'info' => $set_info{'source'},
		'observation' => $set_info{'mjd'},
		'frequencies' => [ $set_info{'config'} ],
		'sets' => [ $sets[$i] ],
		'closure_phase' => [ $closure_phase{'closure_phase'} ]
	    };
	} else {
	    push @{$sources{$set_info{'source'}->{'name'}}->{'frequencies'}},
	    $set_info{'config'};
	    push @{$sources{$set_info{'source'}->{'name'}}->{'sets'}}, $sets[$i];
	    push @{$sources{$set_info{'source'}->{'name'}}->{'closure_phase'}},
	    $closure_phase{'closure_phase'};
	}
    }
}

# Do the measurements.
if ($arguments{'measure-fluxes'} == 1) {
    for my $src (keys %sources) {
	print "MM Measuring flux densities for source ".$src.":\n";
	$sources{$src}->{'flux_density'} =
	    &flux_density_fit($sources{$src}->{'sets'},
			      $arguments{'keep-plots'});
    }
}

my @start_date = mjd2cal($epoch{'mjd'}->{'start'});
my $project_title = "";
if ($epoch{'project_code'} eq 'C007') {
    $project_title = "C007 Calibrator";
} else {
    $project_title = $epoch{'project_code'};
}
my $description_string = sprintf "%s project flux densities from ".
    "%4d-%3s-%02d have been entered into the database.", 
    $project_title, $start_date[2],
    $months[$start_date[1] - 1], $start_date[0];
my %change_summary = (
    'title' => 'New epoch of flux densities available',
    'description' => $description_string
    );
if ($arguments{'remeasure-epoch'} > -1) {
    $description_string = sprintf "%s project flux densities from ".
	"%4d-%3s-%02d have been remeasured", 
	$project_title, $start_date[2],
	$months[$start_date[1] - 1], $start_date[0];
    if (defined $arguments{'reason'}) {
	$description_string .= ": ".$arguments{'reason'};
    }
    if ($description_string !~ /\.$/) {
	$description_string =~ s/\s*$//;
	$description_string .= ".";
    }
    %change_summary = (
	'title' => 'Remeasured flux densities available',
	'description' => $description_string
	);
}

if (!$arguments{'update-db'}) {
    print Dumper(%sources);
    print Dumper(%epoch);
    print Dumper(%change_summary);
} else {
    # Now stick it all into the database.
    print "MM Inserting data into ATCA Calibrator database...\n";
    my $epoch;
    if ($arguments{'same-epoch'} == -1 &&
	$arguments{'remeasure-epoch'} == -1) {
	my $change;
	if ($arguments{'update-changelog'} == 1) {
	    $change = CalDB::Change->insert(
		{
		    'title' => $change_summary{'title'},
		    'description' => $change_summary{'description'}
		});
	}
	$epoch = CalDB::Epoch->insert(
	    {
		'project_code' => $epoch{'project_code'},
		'array' => $epoch{'array'},
		'mjd_start' => $epoch{'mjd'}->{'start'},
		'mjd_end' => $epoch{'mjd'}->{'end'},
		'public' => $arguments{'public'}
	    });
	if ($arguments{'update-changelog'} == 1) {
	    $change->epoch_id($epoch->epoch_id);
	    $change->update;
	}
    } elsif ($arguments{'same-epoch'} > -1) {
	$epoch = CalDB::Epoch->retrieve($arguments{'same-epoch'});
	my $curr_mjd_start = $epoch->mjd_start;
	my $curr_mjd_end = $epoch->mjd_end;
	my $chreq = 0;
	if ($epoch{'mjd'}->{'start'} < $curr_mjd_start) {
	    $epoch->mjd_start($epoch{'mjd'}->{'start'});
	    $chreq = 1;
	}
	if ($epoch{'mjd'}->{'end'} > $curr_mjd_end) {
	    $epoch->mjd_end($epoch{'mjd'}->{'end'});
	    $chreq = 1;
	}
	if ($chreq == 1) {
	    $epoch->update;
	}
    } elsif ($arguments{'remeasure-epoch'} > -1) {
	$epoch = CalDB::Epoch->retrieve($arguments{'remeasure-epoch'});
	if ($arguments{'update-changelog'} == 1) {
	    my $change = CalDB::Change->insert(
		{
		    'title' => $change_summary{'title'},
		    'description' => $change_summary{'description'},
		    'epoch_id' => $epoch->epoch_id
		});
	}
    }
    my @allsrc = keys %sources;
    my $ds = 0;
    for my $src (keys %sources) {
	$ds++;
	print "MM Source: ". $src." (".$ds." / ".($#allsrc + 1).")\n";
	my $measurement;
	if ($arguments{'remeasure-epoch'} == -1) {
	    $measurement = $epoch->add_to_measurements(
		{
		    'source_name' => $sources{$src}->{'info'}->{'name'},
		    'rightascension' => $sources{$src}->{'info'}->{'ra'},
		    'declination' => $sources{$src}->{'info'}->{'dec'},
		    'observation_mjd_start' => $sources{$src}->{'observation'}->{'start'},
		    'observation_mjd_end' => $sources{$src}->{'observation'}->{'end'},
		    'observation_mjd_integration' => $sources{$src}->{'observation'}->{'integration'},
		    'frequency_band' => &frequency_band($sources{$src}->{'frequencies'}->[0]),
		    'public' => $arguments{'public'},
		    'self_calibrated' => $arguments{'self-calibrated'}
		});
	} else {
	    # Find the right measurement.
	    my @meases = CalDB::Measurement->search(
		'source_name' => $sources{$src}->{'info'}->{'name'},
		'frequency_band' => &frequency_band($sources{$src}->{'frequencies'}->[0]),
		'epoch_id' => $epoch->epoch_id,
		'public' => $arguments{'public'},
		'self_calibrated' => $arguments{'self-calibrated'}
		);
	    # Delete all the measurements here.
	    $measurement = $meases[0];
	    if ($measurement) {
		my @freqs = $measurement->frequencies();
		for (my $i=0; $i<=$#freqs; $i++) {
		    $freqs[$i]->delete;
		}
		my @fds = $measurement->fluxdensities();
		for (my $i=0; $i<=$#fds; $i++) {
		    $fds[$i]->delete;
		}
		# Update the RA and Dec in case we've changed them.
		$measurement->rightascension($sources{$src}->{'info'}->{'ra'});
		$measurement->declination($sources{$src}->{'info'}->{'dec'});
		$measurement->update;
	    } else {
		# Allow extra measurements in the remeasure state.
		$measurement = $epoch->add_to_measurements(
		    {
			'source_name' => $sources{$src}->{'info'}->{'name'},
			'rightascension' => $sources{$src}->{'info'}->{'ra'},
			'declination' => $sources{$src}->{'info'}->{'dec'},
			'observation_mjd_start' => $sources{$src}->{'observation'}->{'start'},
			'observation_mjd_end' => $sources{$src}->{'observation'}->{'end'},
			'observation_mjd_integration' => $sources{$src}->{'observation'}->{'integration'},
			'frequency_band' => &frequency_band($sources{$src}->{'frequencies'}->[0]),
			'public' => $arguments{'public'},
			'self_calibrated' => $arguments{'self-calibrated'}
		    });
	    }
	}
	my $fluxdensity = $measurement->add_to_fluxdensities(
	    {
		'fluxdensity_vector_averaged' => $sources{$src}->{'flux_density'}->{'amplitude'}->{'vector_average'},
		'fluxdensity_scalar_averaged' => $sources{$src}->{'flux_density'}->{'amplitude'}->{'scalar_average'},
		'fluxdensity_fit_order' => $sources{$src}->{'flux_density'}->{'fit'}->{'order'},
		'fluxdensity_fit_coeff' => join(',', @{$sources{$src}->{'flux_density'}->{'fit'}->{'coefficients'}}),
		'fluxdensity_fit_scatter' => $sources{$src}->{'flux_density'}->{'fit'}->{'scatter'},
		'phase_vector_averaged' => $sources{$src}->{'flux_density'}->{'phase'}->{'vector_average'},
		'kstest_d' => $sources{$src}->{'flux_density'}->{'fit'}->{'ks_d'},
		'kstest_prob' => $sources{$src}->{'flux_density'}->{'fit'}->{'ks_prob'},
		'reduced_chisquare' => $sources{$src}->{'flux_density'}->{'fit'}->{'reduced_chisquare'}
	    });
	# Rename the plots if we made them.
	if ($arguments{'keep-plots'} == 1) {
	    my $newname = $sources{$src}->{'flux_density'}->{'plotname'};
	    my $plotname = "meas".$measurement->meas_id;
	    $newname =~ s/^(.*\/).*(\.png)$/$1$plotname$2/;
	    my $rcmd = "cp ".$sources{$src}->{'flux_density'}->{'plotname'}." ".
		$newname;
	    system $rcmd;
	}
	for (my $i=0; $i<=$#{$sources{$src}->{'flux_density'}->{'residual'}->{'npoints'}}; $i++) {
	    $fluxdensity->add_to_uvpoints(
		{
		    'uvdistance_bin_centre' => $sources{$src}->{'flux_density'}->{'residual'}->{'uvdistance'}->[$i],
		    'uvdistance_residual_amplitude' => $sources{$src}->{'flux_density'}->{'residual'}->{'amplitude'}->[$i],
		    'uvdistance_bin_npoints' => $sources{$src}->{'flux_density'}->{'residual'}->{'npoints'}->[$i]
		});
	}
	for (my $i=0; $i<=$#{$sources{$src}->{'frequencies'}}; $i++) {
	    my $frequency = $measurement->add_to_frequencies(
		{
		    'frequency_first_channel' => ($sources{$src}->{'frequencies'}->[$i]->{'sfreq'} * 1000),
		    'frequency_channel_interval' => ($sources{$src}->{'frequencies'}->[$i]->{'dfreq'} * 1000),
		    'n_channels' => $sources{$src}->{'frequencies'}->[$i]->{'nchan'},
		    'dataset_name' => $sources{$src}->{'sets'}->[$i]
		});
	    $frequency->add_to_closurephases(
		{
		    'closure_phase_average' => $sources{$src}->{'closure_phase'}->[$i]->{'average_value'},
		    'closure_phase_measured_rms' => $sources{$src}->{'closure_phase'}->[$i]->{'measured_rms'},
		    'closure_phase_theoretical_rms' => $sources{$src}->{'closure_phase'}->[$i]->{'theoretical_rms'}
		});
	}
    }
    print "MM Database updated.\n";
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

sub get_project_code {
    my $set = shift;
    
    my $uvlog = "uvlist.log";
    my $cmd = "uvlist vis=".$set." options=full,variable log=".$uvlog;
    if (-e $uvlog) {
	system "rm -f ".$uvlog;
    }
    &execute_miriad($cmd);

    my $pcode = '';
    open(F, $uvlog);
    while(<F>) {
	chomp;
	my $line = $_;
	if ($line =~ /.*name\s\s\s\s\:([^\s]*)/) {
	    $pcode = $1;
#	    print "DD code = $1\n";
	    $pcode =~ s/.*?\.(.*?)$/$1/;
	}
    }
    close(F);

    return $pcode;
}

sub frequency_band {
    my $r = shift;

    my %bands = (
	'16cm' => { 'lo' => 1, 'hi' => 3.5 },
	'4cm' => { 'lo' => 3.5, 'hi' => 12 },
	'15mm' => { 'lo' => 16, 'hi' => 25 },
	'7mm' => { 'lo' => 30, 'hi' => 50 },
	'3mm' => { 'lo' => 85, 'hi' => 105 }
	);
    for my $b (keys %bands) {
	if ($r->{'sfreq'} >= $bands{$b}->{'lo'} &&
	    $r->{'sfreq'} < $bands{$b}->{'hi'}) {
	    return $b;
	}
    }
    return 'unknown';
}

sub shift_source {
    my $setname = shift;
    my $newra = shift;
    my $newdec = shift;

    print "MM Shifting set ".$setname." to RA,Dec=".$newra.",".
	$newdec."\n";

    my $cmd = "uvedit vis=".$setname." out=".$setname.".uvedit";
    $newra =~ s/\:/\,/g;
    $newdec =~ s/\:/\,/g;
    $cmd .= " ra=".$newra." dec=".$newdec;
    &execute_miriad($cmd);

    # Rename the sets.
    system "mv ".$setname." ".$setname.".orig";
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

sub flux_density_fit {
    my $sets = shift;
    my $makeplot = shift;

    my @rvs;
    my $uvlog = "uvdists.log";
    my $cmd = "uvfmeas stokes=i options=plotvec,log,machine,uvhist,reshist ".
	"log=".$uvlog." vis=".$sets->[0];
    my $plotname = "plots/".$sets->[0].".png";
    for (my $i=1; $i<=$#{$sets}; $i++) {
	$cmd .= ",".$sets->[$i];
    }
    if ($makeplot == 0) {
	$cmd .= " device=/null";
    } else {
	if (!-d "plots") {
	    system "mkdir plots";
	}

	$cmd .= " device=".$plotname."/png";
    }	
    my @fitorders;
    if (defined $arguments{'max-fit-order'}) {
	for (my $i=1; $i<=$arguments{'max-fit-order'}; $i++) {
	    push @fitorders, $i;
	}
    } else {
	push @fitorders, $arguments{'fit-order'};
    }
    for (my $fi=0; $fi<=$#fitorders; $fi++) {
	my $f = $fitorders[$fi];
	my $fcmd = $cmd." order=".$f;
	if (-e $uvlog) {
	    system "rm -f ".$uvlog;
	}
	my @cout = &execute_miriad($fcmd);

	my %rv = (
	    'amplitude' => { 'vector_average' => 0,
			     'scalar_average' => 0 },
	    'phase' => { 'vector_average' => 0 },
	    'fit' => { 'order' => $arguments{'fit-order'},
		       'coefficients' => [],
		       'scatter' => 0,
		       'ks_d' => 1,
		       'ks_prob' => 0,
		       'reduced_chisquare' => 0 },
	    'residual' => { 'uvdistance' => [],
			    'amplitude' => [],
			    'npoints' => [] },
	    'plotname' => $plotname
	    );
	for (my $i=0; $i<=$#cout; $i++) {
	    my @els = split(/\s+/, $cout[$i]);
	    if ($els[2] eq "Amplitude:") {
		if ($els[0] eq "Vector") {
		    $rv{'amplitude'}->{'vector_average'} = $els[3];
		    $rv{'phase'}->{'vector_average'} = $els[5];
		} elsif ($els[0] eq "Scalar") {
		    $rv{'amplitude'}->{'scalar_average'} = $els[3];
		}
	    } elsif ($els[0] eq "Coeff:") {
		my @cf = splice @els, 1;
		$rv{'fit'}->{'coefficients'} = \@cf;
	    } elsif ($els[0] eq "Scatter") {
		$rv{'fit'}->{'scatter'} = $els[3];
	    } elsif ($els[0] eq "KS") {
		$rv{'fit'}->{'ks_d'} = $els[4];
		$rv{'fit'}->{'ks_prob'} = $els[7];
	    } elsif ($els[0] eq "Reduced") {
		$rv{'fit'}->{'reduced_chisquare'} = $els[3];
	    }
	}
	
	# Read in the uv-dist vs residual amplitude log.
	if (-e $uvlog) {
	    open(F, $uvlog);
	    while(<F>) {
		chomp;
		my $line = $_;
		$line =~ s/^\s+//;
		my @els = split(/\s+/, $line);
		if ($els[2] > 0) {
		    push @{$rv{'residual'}->{'uvdistance'}}, $els[0];
		    push @{$rv{'residual'}->{'amplitude'}}, $els[1];
		    push @{$rv{'residual'}->{'npoints'}}, $els[2];
		}
	    }
	    close(F);
	}
	push @rvs, \%rv;
    }

    my ($minscatter, $minsi);
    for (my $i=0; $i<=$#rvs; $i++) {
	if ($i == 0) {
	    $minscatter = $rvs[$i]->{'fit'}->{'scatter'};
	    $minsi = $i;
	} else {
	    if ($rvs[$i]->{'fit'}->{'scatter'} < $minscatter) {
		$minsi = $i;
		$minscatter = $rvs[$i]->{'fit'}->{'scatter'};
	    }
	}
    }

    return $rvs[$minsi];
}

sub measure_closure_phase {
    my $set = shift;

    my $closurelog = "closure_log.txt";
    my $cmd = "closure vis=".$set." stokes=i device=/null options=log";
    if (-e $closurelog) {
	system "rm -f ".$closurelog;
    }
    my @cout = &execute_miriad($cmd);

    my %rv = (
	'closure_phase' => { 'theoretical_rms' => 0, 
			     'measured_rms' => 0,
			     'average_value' => -999 }
	);
    for (my $i=0; $i<=$#cout; $i++) {
	my @els = split(/\s+/, $cout[$i]);
	if ($els[0] eq "Actual") {
	    $rv{'closure_phase'}->{'measured_rms'} = $els[$#els];
	} elsif ($els[0] eq "Theoretical") {
	    $rv{'closure_phase'}->{'theoretical_rms'} = $els[$#els];
	}
    }

    if (-e $closurelog) {
	my @pvals;
	open(F, "closure_log.txt");
	while(<F>) {
	    chomp;
	    my @els = split(/\s+/);
	    if ($#els == 2) {
		push @pvals, $els[2];
	    }
	}
	close(F);
	$rv{'closure_phase'}->{'average_value'} = 
	    sprintf "%.4f", &average(@pvals);
    }

    return %rv;
}

sub average {
    my @a = @_;
    
    my $s = 0;
    for (my $i=0; $i<=$#a; $i++) {
	$s += $a[$i];
    }
    $s /= ($#a + 1);

    return $s;
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

sub project_mode {
    my $a = shift;

    my %b;
    for (my $i=0; $i<=$#{$a}; $i++) {
	if (!defined $b{$a->[$i]}) {
	    $b{$a->[$i]} = 1;
	} else {
	    $b{$a->[$i]}++;
	}
    }

    my $mx = 0;
    my $mb = '';
    for my $c (keys %b) {
	if ($b{$c} > $mx) {
	    $mx = $b{$c};
	    $mb = $c;
	}
    }

    return $mb;
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

sub load_configurations {
    if ($#configuration_strings > -1) {
	# Already loaded and cached.
	return;
    }

    open(ARRAYS, "/n/ste616/src/configuration_stations.file");
    while(<ARRAYS>) {
	chomp;
	push @configuration_strings, $_;
    }
    close(ARRAYS);

    return;
}

sub determine_array {
    my $set = shift;

    # Load the required data.
    &load_configurations();

    # Get the positions of the antennas.
    my $cmd = "uvlist vis=".$set." options=full,array";
    my @cout = &execute_miriad($cmd);

    my %antpos = (
	'x' => [], 'y' => [], 'z' => [] );
    for (my $i=0; $i<=$#cout; $i++) {
	my @els = split(/\s+/, $cout[$i]);
	if ($els[1] > 0 && $els[1] < 7) {
	    $antpos{'x'}->[$els[1] - 1] = $els[2];
	    $antpos{'y'}->[$els[1] - 1] = $els[3];
	    $antpos{'z'}->[$els[1] - 1] = $els[4];
	}
    }

    # Adjust to make antenna 6 the reference.
    for (my $i=0; $i<6; $i++) {
	$antpos{'x'}->[$i] -= $antpos{'x'}->[5];
	$antpos{'y'}->[$i] -= $antpos{'y'}->[5];
	$antpos{'z'}->[$i] -= $antpos{'z'}->[5];
	$antpos{'x'}->[$i] *= -1;
	$antpos{'y'}->[$i] *= -1;
	$antpos{'z'}->[$i] *= -1;
    }

    # The station interval is 15.3m.
    my $station_interval = 15.3;
    my @array_stations;
    for (my $i=0; $i<6; $i++) {
	my $ew_offset = floor(($antpos{'y'}->[$i] / $station_interval) + 0.5) + 392;
	my $ns_offset = floor(($antpos{'x'}->[$i] / $station_interval) + 0.5) + 0;
#	print "CA0".($i + 1)." = ".$ew_offset."\n";
#	print "CA0".($i + 1)." N= ".$ns_offset."\n";
	if ($ns_offset == 0) {
	    push @array_stations, "W".$ew_offset;
	} else {
	    push @array_stations, "N".$ns_offset;
	}
    }

    # Find the best match to the array.
    my $max_matches = 0;
    my $match_array = '';
    for (my $i=0; $i<=$#configuration_strings; $i++) {
	my $curr_match_count = 0;
	for (my $j=0; $j<=$#array_stations; $j++){
	    if ($configuration_strings[$i] =~ /$array_stations[$j]/){
		$curr_match_count++;
	    }
	}
	if ($curr_match_count > $max_matches){
	    $max_matches = $curr_match_count;
	    $match_array = $configuration_strings[$i];
	}
    }

#    print "best matching array ".$match_array."\n";
    return $match_array;
}
