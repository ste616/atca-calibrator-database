#!/usr/bin/perl

# Script for generating C007 schedules based on the information already in the
# database.

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;
use Data::Dumper;

my %arguments = (
    'schedule' => 'c007schedule.sch'
    );
for (my $i = 0; $i <= $#ARGV; $i++) {
    if ($ARGV[$i] eq "--band") {
	$i++;
	# The bandname for the schedule.
	$arguments{'band'} = $ARGV[$i];
    } elsif ($ARGV[$i] eq "--sched") {
	$i++;
	# The name of the output schedule.
	$arguments{'schedule'} = $ARGV[$i];
    }
}

my @bands = ( '16cm', '4cm', '15mm', '7mm', '3mm' );
my @freqs = ( [ 2100, 2100 ], [ 5500, 9000 ], [ 17000, 19000 ],
	      [ 33000, 35000 ], [ 93000, 95000 ] );

my $bf = -1;
for (my $i = 0; $i <= $#bands; $i++) {
    if ($bands[$i] eq $arguments{'band'}) {
	$bf = $i;
    }
}
if ($bf < 0) {
    die "Must specify a band name.\n";
}

# Get a list of all the calibrators.
print "Getting all calibrators...\n";
my @calibrators = CalDB::Calibrator->search_c007();

#for (my $i = 0; $i <= $#calibrators; $i++) {
#    print $calibrators[$i]->name.": ".
#	$calibrators[$i]->rightascension." ".
#	$calibrators[$i]->declination." (".
#	$calibrators[$i]->catalogue.")\n";
#}
print " Done, ".($#calibrators + 1)." calibrators found.\n";

#print Dumper(@calibrators);

# Prioritise those calibrators that have not been observed at all
# at this band.
my @priority_list;
for (my $i = 0; $i <= $#calibrators; $i++) {
    if ($calibrators[$i]->fluxdensities_bands !~ /$arguments{'band'}/) {
	push @priority_list, splice @calibrators, $i, 1;
	$i--;
    }
}
my $cals_no_obs = ($#priority_list + 1);
print "\nFound $cals_no_obs calibrators with no measurements in this band.\n";
print "This leaves ".($#calibrators + 1)." calibrators.\n";

# Find those calibrators that are very bright as seed calibrators.
my @seed_calibrators;
for (my $i = 0; $i <= $#calibrators; $i++) {
    my @cs = &coeff4band($calibrators[$i]->fluxdensities_bands,
			 $arguments{'band'},
			 $calibrators[$i]->fluxdensities_coeffs);
    my $fd = &coeff2flux(\@cs, $freqs[$bf]->[0]);
    if ($fd > 1) {
	push @seed_calibrators, splice @calibrators, $i, 1;
	$i--;
    }
}
print "\nFound ".($#seed_calibrators + 1)." seed calibrators.\n";
print "This leaves ".($#calibrators + 1)." calibrators.\n";

# Get rid of the calibrators with small flux densities.
my @undetected_calibrators;
for (my $i = 0; $i <= $#calibrators; $i++) {
    my @cs = &coeff4band($calibrators[$i]->fluxdensities_bands,
			 $arguments{'band'},
			 $calibrators[$i]->fluxdensities_coeffs);
    my $fd = &coeff2flux(\@cs, $freqs[$bf]->[0]);
    if ($fd < 0.1) {
	push @undetected_calibrators, splice @calibrators, $i, 1;
	$i--;
    }
}
print "\nFound ".($#undetected_calibrators + 1)." undetectable calibrators.\n";
print "This leaves ".($#calibrators + 1)." calibrators.\n";

# Look at the closure phases on the seed calibrators and remove those
# that have bad closure phases.
my @discarded_seeds;
for (my $i = 0; $i <= $#seed_calibrators; $i++) {
    print "searching for ".$seed_calibrators[$i]->name." \n";
    my @ms = CalDB::Measurement->search_closure($seed_calibrators[$i]->name,
						$arguments{'band'});
    my @cls = split(/\,/, $ms[0]->closures);
    if (&average(\@cls) >= 2) {
	push @discarded_seeds, splice @seed_calibrators, $i, 1;
	$i--;
    }
}
print "\nDiscarded ".($#discarded_seeds + 1)." seed calibrators.\n";
print "This leaves ".($#seed_calibrators + 1)." seed calibrators.\n";

# Make sure that no seed calibrator is within 10 degrees of another.
my %collections;
for (my $i = 0; $i <= $#seed_calibrators; $i++) {
    $collections{"s".$seed_calibrators[$i]->name} = {
	'seed' => $seed_calibrators[$i],
	'sources' => []
    };
}
for (my $i = 0; $i < $#seed_calibrators; $i++) {
    for (my $j = $i + 1; $j <= $#seed_calibrators; $j++) {
	my $d = &angdist($seed_calibrators[$i]->ra_decimal,
			 $seed_calibrators[$i]->dec_decimal,
			 $seed_calibrators[$j]->ra_decimal,
			 $seed_calibrators[$j]->dec_decimal);
	if ($d < 10) {
	    push @{$collections{"s".$seed_calibrators[$i]->name}->{'sources'}},
	    splice @seed_calibrators, $j, 1;
	    $j--;
	}
    }
}
print "This leaves ".($#seed_calibrators + 1)." spaced seed calibrators.\n";

my $l = 699;
$l -= ($#seed_calibrators + 1) * 3;
$l -= ($#priority_list + 1) * 2;

# Associate each calibrator with its nearest seed.
print "\nCollecting sources...\n";
for (my $i = 0; $i <= $#priority_list; $i++) {
    my $mindist = 360;
    my $minj = -1;
    for (my $j = 0; $j <= $#seed_calibrators; $j++) {
	my $d = &angdist($priority_list[$i]->ra_decimal,
			 $priority_list[$i]->dec_decimal,
			 $seed_calibrators[$j]->ra_decimal,
			 $seed_calibrators[$j]->dec_decimal);
	if ($d < $mindist) {
	    $mindist = $d;
	    $minj = $j;
	}
    }
    if ($minj >= 0) {
	push @{$collections{"s".$seed_calibrators[$minj]->name}->{'sources'}},
	$priority_list[$i];
    }
}
for (my $i = 0; $i <= $#calibrators; $i++) {
    $l--;
    if ($l <= 0) {
	last;
    }
    my $mindist = 360;
    my $minj = -1;
    for (my $j = 0; $j <= $#seed_calibrators; $j++) {
	my $d = &angdist($calibrators[$i]->ra_decimal,
			 $calibrators[$i]->dec_decimal,
			 $seed_calibrators[$j]->ra_decimal,
			 $seed_calibrators[$j]->dec_decimal);
	if ($d < $mindist) {
	    $mindist = $d;
	    $minj = $j;
	}
    }
    if ($minj >= 0) {
	push @{$collections{"s".$seed_calibrators[$minj]->name}->{'sources'}},
	$calibrators[$i];
    }
}
print " Done.\n";
#print Dumper(%collections);

# Sort the seed calibrators by RA.
my @sorted_seeds = sort { $a->ra_decimal <=> $b->ra_decimal } @seed_calibrators;
open(S, ">".$arguments{'schedule'});
for (my $i = 0; $i <= $#sorted_seeds; $i++) {
    for (my $j = 0; $j < 3; $j++) {
	&schedoutput_start(S);
	if ($i == 0 && $j == 0) {
	    &schedoutput_preamble(S, "C007", $freqs[$bf]);
	}
	if ($j == 0) {
	    &schedoutput_source(S, $sorted_seeds[$i], "00:02:00", "point");
	} elsif ($j == 1) {
	    &schedoutput_source(S, $sorted_seeds[$i], "00:02:00", "paddle");
	} elsif ($j == 2) {
	    &schedoutput_source(S, $sorted_seeds[$i], "00:04:00", "offset");
	}
	&schedoutput_end(S);
    }
    my $r = $collections{"s".$sorted_seeds[$i]->name};
    for (my $j = 0; $j < $#{$r->{'sources'}}; $j++) {
	&schedoutput_start(S);
	if ($j > 0 && ($j % 5 == 0)) {
	    &schedoutput_source(S, $r->{'sources'}->[$j], "00:02:00", "paddle");
	    &schedoutput_end(S);
	    &schedoutput_start(S);
	}
	&schedoutput_source(S, $r->{'sources'}->[$j], "00:04:00", "offset");
	&schedoutput_end(S);
    }
}
close(S);

sub schedoutput_source {
    my $h = shift;
    my $src = shift;
    my $time = shift;
    my $type = shift;

    print $h "Source=".$src->name."\n";
    print $h "RA=".$src->rightascension."\n";
    print $h "Dec=".$src->declination."\n";
    print $h "ScanLength=$time\n";
    print $h "CalCode=C\n";
    if ($type eq "point") {
	print $h "ScanType=Point\n";
	print $h "Pointing=Update\n";
    } elsif ($type eq "paddle") {
	print $h "ScanType=Paddle\n";
	print $h "Pointing=Offset\n";
    } elsif ($type eq "dwell" ||
	     $type eq "offset") {
	print $h "ScanType=Dwell\n";
	if ($type eq "offset") {
	    print $h "Pointing=Offset\n";
	} else {
	    print $h "Pointing=Global\n";
	}
    }

}

sub schedoutput_preamble {
    my $h = shift;
    my $project = shift;
    my $freqarr = shift;

    print $h "Project=$project\n";
    print $h "PointingOffset1=0.000\n";
    print $h "PointingOffset2=0.000\n";
    print $h "Epoch=J2000\n";
    print $h "Freq-1=".$freqarr->[0]."\n";
    print $h "Freq-2=".$freqarr->[1]."\n";
}

sub schedoutput_start {
    my $h = shift;

    print $h "\$SCAN*V5\n";
}

sub schedoutput_end {
    my $h = shift;

    print $h "\$SCANEND\n";
}

sub angdist {
    my $ra1 = shift;
    my $dec1 = shift;
    my $ra2 = shift;
    my $dec2 = shift;

    my $adec = ($dec1 + $dec2) / 2;
    my $radiff = ($ra1 - $ra2) * cos($adec * 3.1415926536 / 180);
    my $d = sqrt($radiff**2 + ($dec1 - $dec2)**2);
    
    return $d;
}

sub average {
    my $aref = shift;

    my $s = 0;
    my $n = 0;
    for (my $i = 0; $i <= $#{$aref}; $i++) {
	$s += $aref->[$i];
	$n++;
    }
    if ($n > 0) {
	return ($s / $n);
    }
    return 0;
}

sub coeff4band {
    my $bandstr = shift;
    my $reqband = shift;
    my $coeffstr = shift;

    my @b = split(/\,/, $bandstr);
    my @c = split(/\//, $coeffstr);
    for (my $i = 0; $i <= $#b; $i++) {
	if ($b[$i] eq $reqband) {
	    my @cs = split(/\,/, $c[$i]);
	    return @cs;
	}
    }
    return undef;
}

sub coeff2flux {
    my $coeff = shift;
    my $freq = shift;

    $freq /= 1000;

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
