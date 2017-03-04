#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;
use Data::Dumper;
use Statistics::Descriptive;
use strict;

# Go through the calibrator database and update some summary information
# so calibrator searches are fast and the statistics page can be
# generated in a reasonable time.
my %arguments = (
    'update-latest' => 1,
    'update-measurements' => 1,
    'update-summaries' => 1,
    'update-qualities' => 1
    );
for (my $i = 0; $i <= $#ARGV; $i++) {
    if ($ARGV[$i] eq "--skip-latest") {
	# Don't update the latest measurement pointers.
	$arguments{'update-latest'} = 0;
    } elsif ($ARGV[$i] eq "--skip-measurements") {
	# Don't update the measurement calculations.
	$arguments{'update-measurements'} = 0;
    } elsif ($ARGV[$i] eq "--skip-summaries") {
	# Don't update the epoch summaries.
	$arguments{'update-summaries'} = 0;
    } elsif ($ARGV[$i] eq "--skip-qualities") {
	# Don't update the calibrator qualities.
	$arguments{'update-qualities'} = 0;
    }
}

# Step 1. Go through each calibrator in the database and find the latest
# information in each band.
my @bands = ( '16cm', '4cm', '15mm', '7mm', '3mm' );

if ($arguments{'update-latest'} == 1) {
    print "1. Updating latest measurement pointers...\n";
    my $cal_iterator = CalDB::Calibrator->retrieve_all;
    while (my $cal = $cal_iterator->next) {
	print "  Calibrator: ".$cal->name;
	my $needsupdate = 0;
	for (my $i=0; $i<=$#bands; $i++) {
	    print " ".$bands[$i];
	    my $meas_iterator = CalDB::Measurement->search(
		'source_name' => $cal->name,
		'frequency_band' => $bands[$i],
		'public' => 1,
		{ 'order_by' => 'observation_mjd_start DESC' } );
	    if (my $meas = $meas_iterator->next) {
		print "(Y)";
		my $method = "latest_".$bands[$i];
		if ($cal->can($method)) {
		    $cal->$method($meas->meas_id);
		    $needsupdate = 1;
		}
	    } else {
		print "(N)";
	    }
	}
	print "\n";
	if ($needsupdate == 1) {
	    $cal->update;
	}
    }
    print "\n";
}

# Step 2. Go through each of the measurements and calculate a
# representative flux density for it, if it hasn't been done already.
my %band_frequencies = ( 
    '16cm' => 2100, 
    '4cm' => 5500, 
    '15mm' => 17000, 
    '7mm' => 33000, 
    '3mm' => 93000 );

if ($arguments{'update-measurements'} == 1) {
    print "2. Updating flux density summary measurements...\n";
    my $sql = "band_fluxdensity IS NULL";
    my $meas_iterator = CalDB::Measurement->retrieve_from_sql($sql);
    while (my $meas = $meas_iterator->next) {
	my @fds = $meas->fluxdensities();
	my $freq = $band_frequencies{$meas->frequency_band};
	$meas->band_fluxdensity_frequency($freq);
	my @coeffs = split(/\,/, $fds[0]->fluxdensity_fit_coeff);
	my $f = sprintf "%.3f", &coeff2flux(\@coeffs, ($freq / 1000));
	$meas->band_fluxdensity($f);
	$meas->update;
	print "  ".$meas->source_name." ".$meas->frequency_band." ".$f." Jy\n";
    }
    
    print "\n";
}

# Step 3. Go through and make summaries for each epoch that needs it.
if ($arguments{'update-summaries'} == 1) {
    print "3. Updating epoch summaries...\n";
    my $epoch_iterator = CalDB::Epoch->retrieve_all;
    while (my $epoch = $epoch_iterator->next) {
	my @summaries = $epoch->summaries();
	if ($#summaries >= 0) {
	    next;
	}
	my %sources = ( 'all' => {} );
	my %integration = ( 'all' => 0 );
	my $meas_iterator = $epoch->measurements();
	while (my $meas = $meas_iterator->next) {
	    if (!defined $sources{$meas->frequency_band}) {
		$sources{$meas->frequency_band} = {};
		$integration{$meas->frequency_band} = 0;
	    } 
	    if (!defined $sources{$meas->frequency_band}->{$meas->source_name}) {
		$sources{$meas->frequency_band}->{$meas->source_name} = "yes";
	    }
	    if (!defined $sources{'all'}->{$meas->source_name}) {
		$sources{'all'}->{$meas->source_name} = "yes";
	    }
	    $integration{'all'} += ($meas->observation_mjd_integration * 86400);
	    $integration{$meas->frequency_band} += ($meas->observation_mjd_integration * 86400);
	}
	
	my @b = keys %integration;
	for (my $i = 0; $i <= $#b; $i++) {
	    my @srcs = keys %{$sources{$b[$i]}};
	    print " E=".$epoch->epoch_id." ".$b[$i]." N=".($#srcs + 1)." T=".
		$integration{$b[$i]}."\n";
	    $epoch->add_to_summaries(
		{
		    'frequency_band' => $b[$i],
		    'n_sources' => ($#srcs + 1),
		    'integration_time' => $integration{$b[$i]}
		});
	}
    }
    print "\n";
}

my %arrayNames = ( '6A' => "6km", '6B' => "6km", '6C' => "6km", '6D' => "6km",
		   '1.5A' => "1.5km", '1.5B' => "1.5km", '1.5C' => "1.5km", '1.5D' => "1.5km",
		   '750A' => "750m", '750B' => "750m", '750C' => "750m", '750D' => "750m",
		   'EW367' => "small", 'EW352' => "small", 'H214' => "small", 'H168' => "small",
		   'H75' => "small" );

# Step 4. Determine the quality of each calibrator as a function of array size and band.
if ($arguments{'update-qualities'} == 1) {
    print "4. Updating calibrator qualities.";
    my $cal_iterator = CalDB::Calibrator->retrieve_all;
    while (my $cal = $cal_iterator->next) {
	print "  Calibrator: ".$cal->name."\n";
	my @measurements = CalDB::Measurement->search_allinformation($cal->name);
	my %arraySpecs;
	foreach my $a (keys %arrayNames) {
	    if (!defined $arraySpecs{$arrayNames{$a}}) {
		$arraySpecs{$arrayNames{$a}} = {};
		for (my $i = 0; $i <= $#bands; $i++) {
		    $arraySpecs{$arrayNames{$a}}->{$bands[$i]} = {
			'closurePhases' => [], 'defects' => [],
			'fluxDensities' => [], 'closurePhaseMedian' => -999,
			'defectMedian' => -999, 'fluxDensityMedian' => -999,
			'fluxDensityStdDev' => -999, 'qualityFlag' => -1
		    };
		}
	    }
	}
	for (my $i = 0; $i <= $#measurements; $i++) {
	    my $meas = $measurements[$i];
	    my @cs = split(/\,/, $meas->fluxdensity_fit_coeff);
	    my @aels = split(/\s+/, $meas->array);
	    my $a = $aels[0];
	    my $b = $meas->frequency_band;
	    if (defined $arrayNames{$a}) {
		my $arr = $arrayNames{$a};
		my @f_closure_phase_averages = split(/\,/, $meas->f_closure_phase_average);
		for (my $j = 0; $j <= $#f_closure_phase_averages; $j++) {
		    push @{$arraySpecs{$arr}->{$b}->{'closurePhases'}}, $f_closure_phase_averages[$j];
		}
		my $defect = ($meas->fluxdensity_scalar_averaged / $meas->fluxdensity_vector_averaged) - 1;
		push @{$arraySpecs{$arr}->{$b}->{'defects'}}, $defect;
		my $fd = &coeff2flux(\@cs, ($band_frequencies{$b} / 1000));
		push @{$arraySpecs{$arr}->{$b}->{'fluxDensities'}}, $fd;
	    }
	}
	# Do some calculations.
	foreach my $a (keys %arraySpecs) {
	    for (my $i = 0; $i <= $#bands; $i++) {
		my $r = $arraySpecs{$a}->{$bands[$i]};
		if ($#{$r->{'closurePhases'}} >= 0) {
		    my $stat_closurePhases = Statistics::Descriptive::Full->new();
		    $stat_closurePhases->add_data($r->{'closurePhases'});
		    $r->{'closurePhaseMedian'} = $stat_closurePhases->median();
		}
		if ($#{$r->{'defects'}} >= 0) {
		    my $stat_defects = Statistics::Descriptive::Full->new();
		    $stat_defects->add_data($r->{'defects'});
		    $r->{'defectMedian'} = $stat_defects->median();
		}
		if ($#{$r->{'fluxDensities'}} >= 0) {
		    my $stat_fluxDensities = Statistics::Descriptive::Full->new();
		    $stat_fluxDensities->add_data($r->{'fluxDensities'});
		    $r->{'fluxDensityMedian'} = $stat_fluxDensities->median();
		    $r->{'fluxDensityStdDev'} = $stat_fluxDensities->standard_deviation();
		}
		# And calculate the quality.
		if (($r->{'closurePhaseMedian'} != -999) &&
		    ($r->{'defectMedian'} != -999) &&
		    ($r->{'fluxDensityMedian'} != -999) &&
		    ($r->{'fluxDensityStdDev'} != -999)) {
		    $r->{'qualityFlag'} = 4; # This is the maximum value.
		    if ($r->{'closurePhaseMedian'} >= 3) {
			$r->{'qualityFlag'} -= 1;
		    }
		    if ($r->{'closurePhaseMedian'} >= 10) {
			$r->{'qualityFlag'} -= 1;
		    }
		    if ($r->{'defectMedian'} >= 1.05) {
			$r->{'qualityFlag'} -= 1;
		    }
		    if ($r->{'fluxDensityStdDev'} > ($r->{'fluxDensityMedian'} / 2)) {
			$r->{'qualityFlag'} -= 1;
		    }
		    print "    quality at $bands[$i] for $a array: ".$r->{'qualityFlag'}."\n";
		    if (($a eq "6km") && ($bands[$i] eq "16cm")) {
			$cal->quality_6000_16($r->{'qualityFlag'});
		    } elsif (($a eq "6km") && ($bands[$i] eq "4cm")) {
			$cal->quality_6000_4($r->{'qualityFlag'});
		    } elsif (($a eq "6km") && ($bands[$i] eq "15mm")) {
			$cal->quality_6000_15($r->{'qualityFlag'});
		    } elsif (($a eq "6km") && ($bands[$i] eq "7mm")) {
			$cal->quality_6000_7($r->{'qualityFlag'});
		    } elsif (($a eq "6km") && ($bands[$i] eq "3mm")) {
			$cal->quality_6000_3($r->{'qualityFlag'});
		    } elsif (($a eq "1.5km") && ($bands[$i] eq "16cm")) {
			$cal->quality_1500_16($r->{'qualityFlag'});
		    } elsif (($a eq "1.5km") && ($bands[$i] eq "4cm")) {
			$cal->quality_1500_4($r->{'qualityFlag'});
		    } elsif (($a eq "1.5km") && ($bands[$i] eq "15mm")) {
			$cal->quality_1500_15($r->{'qualityFlag'});
		    } elsif (($a eq "1.5km") && ($bands[$i] eq "7mm")) {
			$cal->quality_1500_7($r->{'qualityFlag'});
		    } elsif (($a eq "1.5km") && ($bands[$i] eq "3mm")) {
			$cal->quality_1500_3($r->{'qualityFlag'});
		    } elsif (($a eq "750m") && ($bands[$i] eq "16cm")) {
			$cal->quality_750_16($r->{'qualityFlag'});
		    } elsif (($a eq "750m") && ($bands[$i] eq "4cm")) {
			$cal->quality_750_4($r->{'qualityFlag'});
		    } elsif (($a eq "750m") && ($bands[$i] eq "15mm")) {
			$cal->quality_750_15($r->{'qualityFlag'});
		    } elsif (($a eq "750m") && ($bands[$i] eq "7mm")) {
			$cal->quality_750_7($r->{'qualityFlag'});
		    } elsif (($a eq "750m") && ($bands[$i] eq "3mm")) {
			$cal->quality_750_3($r->{'qualityFlag'});
		    } elsif (($a eq "small") && ($bands[$i] eq "16cm")) {
			$cal->quality_375_16($r->{'qualityFlag'});
		    } elsif (($a eq "small") && ($bands[$i] eq "4cm")) {
			$cal->quality_375_4($r->{'qualityFlag'});
		    } elsif (($a eq "small") && ($bands[$i] eq "15mm")) {
			$cal->quality_375_15($r->{'qualityFlag'});
		    } elsif (($a eq "small") && ($bands[$i] eq "7mm")) {
			$cal->quality_375_7($r->{'qualityFlag'});
		    } elsif (($a eq "small") && ($bands[$i] eq "3mm")) {
			$cal->quality_375_3($r->{'qualityFlag'});
		    }
		    $cal->update;
		} else {
		    print "    quality undetermined\n";
		}
	    }
	}
    }
}

sub coeff2flux {
    my $coeff = shift;
    my $freq = shift;

    my $s = $coeff->[0];
    my $lf = log($freq) / log(10);
    if ($coeff->[$#{$coeff}] ne 'log') {
	$lf = $freq;
    }
    for (my $i=1; $i<$#{$coeff}; $i++) {
	$s += $coeff->[$i] * $lf**$i;
    }
    if ($coeff->[$#{$coeff}] eq 'log') {
	$s = 10**$s;
    }
    return $s;
}
