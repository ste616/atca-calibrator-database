#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;

use strict; use warnings;

my @cals = CalDB::Measurement->search_allfluxdensities();

print "source_name  rightascens   declination  observation_mjd_start  observation_mjd_end  observation_mjd_integration  frequency_band  epoch_id  band_fluxdensity  band_fluxdensity_frequency   fluxdensity_scatter  fluxdensity_fit_coeff\n";
for (my $i=0; $i <= $#cals; $i++) {
    my $bfd = $cals[$i]->band_fluxdensity;
    my $bff = $cals[$i]->band_fluxdensity_frequency;
    if ($bfd eq "") {
	$bfd = "0.0";
    }
    if ($bff eq "") {
	$bff = "0.000000";
    }
    printf "%11s  %11s  %12s  %21s  %19s  %27s  %14s  %8s  %16s  %26s  %20s  %30s\n",$cals[$i]->source_name,
    $cals[$i]->rightascension, $cals[$i]->declination,
    $cals[$i]->observation_mjd_start,$cals[$i]->observation_mjd_end,$cals[$i]->observation_mjd_integration,
    $cals[$i]->frequency_band,$cals[$i]->epoch_id,$bfd,$bff,
    $cals[$i]->fluxdensity_fit_scatter, $cals[$i]->fluxdensity_fit_coeff;
}
