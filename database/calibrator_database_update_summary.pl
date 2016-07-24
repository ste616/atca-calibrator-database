#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;
use Data::Dumper;

# Go through the calibrator database and update some summary information
# so calibrator searches are fast and the statistics page can be
# generated in a reasonable time.
my %arguments = (
    'update-latest' => 1,
    'update-measurements' => 1,
    'update-summaries' => 1
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
