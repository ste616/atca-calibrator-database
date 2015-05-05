#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;
use Data::Dumper;

# Change the public flag for any measurement that has "NaN" coefficients.

# Get all the bad measurements.
my $badmeas_iterator = CalDB::Measurement->search_notnumbers();
while (my $badmeas = $badmeas_iterator->next) {
    print " Measurement ".$badmeas->meas_id." flux ".$badmeas->flux_id.
	" coeff=".$badmeas->fluxdensity_fit_coeff." (public=".
	$badmeas->public.")\n";
    # Set the public flag to 0.
    $badmeas->public(0);
    $badmeas->update;
}

# Change the public flag for any measurement that has a very small or
# negative representative flux density.

my $lowflux_iterator = CalDB::Measurement->search_smallflux(0.001);
while (my $lowflux = $lowflux_iterator->next) {
    print " Measurement ".$lowflux->meas_id." flux ".$lowflux->band_fluxdensity."\n";
    # Set the public flag to 0.
    $lowflux->public(0);
    $lowflux->update;
}
