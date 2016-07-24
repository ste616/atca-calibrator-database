#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;

use strict; use warnings;

my @cals = CalDB::Measurement->search_allfluxdensities();

print "source_name  observation_mjd_start  observation_mjd_end  observation_mjd_integration  frequency_band  epoch_id  band_fluxdensity  band_fluxdensity_frequency\n";
for (my $i=0; $i <= $#cals; $i++) {
    printf "%11s  %21s  %19s  %27s  %14s  %8s  %16s  %26s\n",$cals[$i]->source_name,
    $cals[$i]->observation_mjd_start,$cals[$i]->observation_mjd_end,$cals[$i]->observation_mjd_integration,
    $cals[$i]->frequency_band,$cals[$i]->epoch_id,$cals[$i]->band_fluxdensity,
    $cals[$i]->band_fluxdensity_frequency;
}
