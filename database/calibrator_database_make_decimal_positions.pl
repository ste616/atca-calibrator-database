#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;
use Astro::Time;
use Data::Dumper;

# Take the sexagesimal positions for each calibrator in the calibrator list,
# convert it to decimal degrees and insert this back into the appropriate
# column for later use for position based searches.

my $cal_iterator = CalDB::Calibrator->retrieve_all;
while (my $cal = $cal_iterator->next) {
    print "  Calibrator: ".$cal->name." RA=".$cal->rightascension.
	" Dec=".$cal->declination."\n";
    my $dra = sprintf "%.9f", str2deg($cal->rightascension, 'H');
    my $ddec = sprintf "%.9f", str2deg($cal->declination, 'D');
    $cal->ra_decimal($dra);
    $cal->dec_decimal($ddec);
    $cal->update;
}

