#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBweb;
use CalDB;
use CGI qw(:standard);
use Data::Dumper;
use Astro::Time;
use JSON;

use strict; use warnings;

my $in = CGI->new;
my %input = $in->Vars;

# Some info that isn't in the database.
my %quality =
    ( "atca-a" => "0 &lt; &#963; &lt; 0.02 arcsec [<a href=/calibrators/c007/atcat.html>AT.CAT</a>]",
      "atca-b" => "0.02 &lt; &#963; &lt; 0.10 arcsec [<a href=/calibrators/c007/atcat.html>AT.CAT</a>]",
      "atca-c" => "0.10 &lt; &#963; &lt; 0.25 arcsec [<a href=/calibrators/c007/atcat.html>AT.CAT</a>]",
      "atca-d" => "0.15 &lt; &#963; &lt; 0.50 arcsec",
      "atca-s" => "&#963; &gt; 0.25 arcsec [<a href=/calibrators/c007/atcat.html>AT.CAT</a>]",
      "vla-a"  => "&#963; &lt; 0.002 arcsec [VLA calibrator manual]",
      "vla-b"  => "0.002 &lt; &#963; &lt; 0.01 arcsec [VLA calibrator manual]",
      "vla-c"  => "0.01 &lt; &#963; &lt; 0.15 arcsec [VLA calibrator manual]",
      "vla-t"  => "&#963; &gt; 0.15 arcsec [VLA calibrator manual]",
      "lcs1" => "&#963; &lt; 0.003 arcsec [<a href=".&bibcode("2011MNRAS.414.2528P").">Petrov et al 2011</a>]",
      "fom" => "VLBI [<a href=".&bibcode("2003AJ....126.2562F").">Fomalont et al 2003</a>]",
      "wright" => "[<a href=http://www.parkes.atnf.csiro.au/databases/surveys/pmn/casouth.pdf>Wright et al 1997</a>]",
      "rojha" => "VLBI [<a href=".&bibcode("2004AJ....127.1791F").">Fey et al 2004</a> and".
      " <a href=".&bibcode("2004AJ....128.2593F").">Fey et al 2004</a>]",
      "crf2005b" => "VLBI [<a href=http://rorf.usno.navy.mil/solutions/>ICRF Ext2</a>]",
      "rorf" => "VLBI [<a href=".&bibcode("1995AJ....110..880J").">Johnston et al 1995</a>]");

my @months = ( 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
	       'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC' );

my $action = $input{'action'};
#$action = "info";
#$input{'source'} = "j0321-3711";
#$action="names";
#$action="changes";
#$action = "band_fluxdensity";
#$action = "band_quality";
#$action = "band_timeseries";
#$action = "band_uvpoints";
#$input{'band'} = "4cm";
#$action="search";
#$input{'position'} = "12:56:11,-05:47:22";
#$input{'radius'} = 10;
#$input{'rarange'} = "21,2";
#$input{'decrange'} = "-40,0";
#$input{'flux_limit'} = 0.1;
#$input{'flux_limit_band'} = "4cm";
#$input{'allow_no_measurements'} = 0;
#$action = "epochs";
#$action = "epoch_summary";
#$action = "epoch_details";
#$input{'epoch_id'} = 5;
#$action = "source_all_details";
#$input{'source'} = "0420-625";
#$input{'mode'} = "cals";
#$input{'radec'} = "12:56:11.166560,-05:47:21.524580";
#$input{'type'} = "j2000";
#$input{'theta'} = 20;
#$input{'flimit'} = 0.125;
#$input{'frequencies'} = "2100,2100";

if (!$input{'mode'} || $input{'mode'} ne "cals") {
    print $in->header('text/json');
}

my %output;

if ($action && $action eq 'info') {
    if (!$input{'source'}) {
	$output{'error'} = "No source specified.";
    } else {
	%output = &get_information($input{'source'});
    }
} elsif ($action && $action eq 'names') {
    %output = &get_calibrator_names();
} elsif ($action && $action eq "changes") {
    %output = &get_recent_changes($input{'nchanges'});
} elsif ($action && $action eq "band_fluxdensity") {
    if (!$input{'source'} ||
	!$input{'band'}) {
	$output{'error'} = "No source or band specified.";
    } else {
	%output = &get_band_fluxdensity($input{'source'}, $input{'band'});
    }
} elsif ($action && $action eq "band_quality") {
    if (!$input{'source'} ||
	!$input{'band'}) {
	$output{'error'} = "No source or band specified.";
    } else {
	%output = &get_band_quality($input{'source'}, $input{'band'});
    }
} elsif ($action && $action eq "band_timeseries") {
    if (!$input{'source'} ||
	!$input{'band'}) {
	$output{'error'} = "No source or band specified.";
    } else {
	%output = &get_band_timeseries($input{'source'}, $input{'band'});
    }
} elsif ($action && $action eq "band_uvpoints") {
    if (!$input{'source'} ||
	!$input{'band'}) {
	$output{'error'} = "No source or band specified.";
    } else {
	%output = &get_band_uvpoints($input{'source'}, $input{'band'});
    }
} elsif ($action && $action eq "search") {
    if ((!$input{'position'} ||
	 !$input{'radius'}) &&
	(!$input{'rarange'} ||
	 !$input{'decrange'})) {
	$output{'error'} = "No search parameters specified.";
    } else {
	if (!defined $input{'allow_no_measurements'}) {
	    $input{'allow_no_measurements'} = 1;
	}
	%output = &find_calibrators($input{'position'}, $input{'radius'},
				    $input{'rarange'}, $input{'decrange'},
				    $input{'flux_limit'}, $input{'flux_limit_band'},
				    $input{'allow_no_measurements'}, 0);
    }
} elsif ($action && $action eq "epochs") {
    my %options;
    if ($input{'projectcode'}) {
	$options{'project'} = $input{'projectcode'};
    }
    if ($input{'showall'}) {
	$options{'all'} = $input{'showall'};
    }
    %output = &get_epoch_list(\%options);
} elsif ($action && $action eq "epoch_summary") {
    if (!$input{'epoch_id'}) {
	$output{'error'} = "No epoch ID specified.";
    } else {
	%output = &get_epoch_summary($input{'epoch_id'});
    }
} elsif ($action && $action eq "epoch_details") {
    if (!$input{'epoch_id'}) {
	$output{'error'} = "No epoch ID specified.";
    } else {
	my %options;
	if ($input{'showall'}) {
	    $options{'all'} = $input{'showall'};
	}
	%output = &get_epoch_data($input{'epoch_id'}, \%options);
    }
} elsif ($action && $action eq "source_all_details") {
    if (!$input{'source'}) {
	$output{'error'} = "No source specified.";
    } else {
	%output = &get_all_source_details($input{'source'});
    }
} elsif ($input{'mode'} && $input{'mode'} eq "cals") {
    # A request from the web scheduler.
    
    print "Content-type: text/xml\n";
    print "\n<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n";
    print "<caltable>\n";
    print "<heading>The following table gives calibrator sources near ".
	$input{'radec'}.". Note that the presence of a source in this table ".
	"does not necessarily mean it is a good calibrator for your purposes. ".
	"Please click on the link of a prospective calibrator to check its ".
	"suitability. Flux densities should be taken as a guide only. The ".
	"fluxes are taken from a variety of sources of differing accuracy. ".
	"Calibrator fluxes are often variable, perhaps significantly so.</heading>\n";
    &get_scheduler_info($input{'radec'}, $input{'theta'},
			$input{'flimit'}, $input{'frequencies'});
    print "</caltable>\n";
    exit;
}


#print Dumper(%output);

my $json = JSON->new;
$json = $json->allow_blessed(1);
$json = $json->convert_blessed(1);

print $json->utf8->encode(\%output);

#print "\n";

exit;

sub get_scheduler_info {
    my $radec = shift;
    my $theta = shift;
    my $flimit = shift;
    my $frequencies = shift;

    # Use the already present routine to find calibrators.
    my $band = &freq2band($frequencies);
    my %joutput = &find_calibrators(
	$radec, $theta, undef, undef, $flimit, $band, 0, 1
	);
    # Figure out what frequencies we determine for.
    my @fs = split(/\,/, $frequencies);
    # Get the flux density models.
    my @matches = @{$joutput{'matches'}};
    my @smatches = sort { $a->{'angular_distance'} <=> $b->{'angular_distance'} } @matches;
    for (my $i = 0; $i <= $#smatches; $i++) {
	for (my $j = 0; $j <= $#{$smatches[$i]->{'flux_densities'}}; $j++) {
	    if ($smatches[$i]->{'flux_densities'}->[$j]->{'bandname'} eq $band) {
#		my @fdm = CalDB::FluxDensity->search(
#		    'meas_id' => $smatches[$i]->{'flux_densities'}->[$j]->{'measurement'}
#		    );
		my $ra = $smatches[$i]->{'rightascension'};
		$ra =~ s/^(.*\..).*$/$1/;
		my $dec = $smatches[$i]->{'declination'};
		$dec =~ s/^(.*\..).*$/$1/;
		my $os = sprintf "<source><name>%s</name><distance>%.2f</distance>".
		    "<rightascension>%s</rightascension><declination>%s</declination><ra>%s</ra>".
		    "<dec>%s</dec>", $smatches[$i]->{'name'},
		    ($smatches[$i]->{'angular_distance'} * 360), $ra, $dec,
		    $smatches[$i]->{'rightascension'}, $smatches[$i]->{'declination'};
		for (my $k = 0; $k <= $#fs; $k++) {
#		    my @coeffs = split(/\,/, $fdm[0]->fluxdensity_fit_coeff);
		    my @coeffs = split(/\,/, $smatches[$i]->{'flux_densities'}->[$j]->{'flux_coeffs'});
		    my $fluxd = &coeff2flux(
			\@coeffs,
			($fs[$k] / 1000)
			);
		    $os .= sprintf "<fflux%d>%.2f</fflux%d><ffreq%d>%s</ffreq%d>",
		    ($k + 1), $fluxd, ($k + 1), ($k + 1), $fs[$k], ($k + 1);
		}
		$os .= "</source>";
		print $os."\n";
	    }
	}
    }
}

sub get_all_source_details {
    my $source = shift;
    
    # Get pretty much all the information about a source.
    my %output = (
	'source_name' => $source,
	'measurements' => []
	);
    my $meas_iterator = CalDB::Measurement->search(
	'source_name' => $source,
	'public' => 1
	);
    while (my $meas = $meas_iterator->next) {

	# Get the epoch.
	my @epochs = CalDB::Epoch->search(
	    'epoch_id' => $meas->epoch_id
	    );

	my %mres = (
	    'rightascension' => $meas->rightascension,
	    'declination' => $meas->declination,
	    'integration' => $meas->observation_mjd_integration,
	    'project_code' => $epochs[0]->project_code,
	    'array' => $epochs[0]->array,
	    'epoch_start' => $epochs[0]->mjd_start,
	    'frequency_band' => $meas->frequency_band,
	    'frequencies' => [],
	    'fluxdensities' => []
	    );
	
	# Go through the frequencies.
	my $freq_iterator = $meas->frequencies();
	while (my $freq = $freq_iterator->next) {
	    my %fres = (
		'frequency_first' => $freq->frequency_first_channel,
		'frequency_interval' => $freq->frequency_channel_interval,
		'nchans' => $freq->n_channels,
		'closure_phases' => []
		);
	    
	    # Go through the closure phases.
	    my $clos_iterator = $freq->closurephases();
	    while (my $clos = $clos_iterator->next) {
		my %cres = (
		    'closure_phase_average' => $clos->closure_phase_average,
		    'closure_phase_measured_rms' => $clos->closure_phase_measured_rms,
		    'closure_phase_theoretical_rms' => $clos->closure_phase_theoretical_rms
		    );
		push @{$fres{'closure_phases'}}, \%cres;
	    }
	    push @{$mres{'frequencies'}}, \%fres;
	}

	# Go through the flux densities.
	my $flux_iterator = $meas->fluxdensities();
	while (my $flux = $flux_iterator->next) {
	    my @cs = split(/\,/, $flux->fluxdensity_fit_coeff);
	    my %lres = (
		'fluxdensity_vector_averaged' => $flux->fluxdensity_vector_averaged,
		'fluxdensity_scalar_averaged' => $flux->fluxdensity_scalar_averaged,
		'fluxdensity_fit_coeff' => \@cs,
		'fluxdensity_fit_scatter' => $flux->fluxdensity_fit_scatter,
		'phase_vector_averaged' => $flux->phase_vector_averaged
		);
	    push @{$mres{'fluxdensities'}}, \%lres;
	}
	push @{$output{'measurements'}}, \%mres;
    }

    return %output;
}

sub find_calibrators {
    my $position = shift;
    my $radius = shift;
    my $rarange = shift;
    my $decrange = shift;
    my $flux_limit = shift;
    my $flux_limit_band = shift;
    my $allow_no_measurements = shift;
    my $scheduler_mode = shift;

    # Determine which mode to operate in.
    my $mode = "";
    if (defined $position && defined $radius) {
	$mode = "cone";
    } elsif (defined $rarange && defined $decrange) {
	$mode = "slab";
    }

    # Find all the calibrators with measurements within
    # a specified radius of the specified position, and
    # that optionally have their most recent flux brighter
    # than a specified flux limit in the specified band.
    my %output = (
	'search-parameters' => {
	    'flux_limit' => $flux_limit,
	    'flux_limit_band' => $flux_limit_band,
	    'allow_no_measurements' => ($allow_no_measurements) ?
		JSON::true : JSON::false
	},
	'matches' => []
	);
    if ($mode eq "cone") {
	$output{'search-parameters'}->{'position'} = $position;
	$output{'search-parameters'}->{'radius'} = $radius;
    } elsif ($mode eq "slab") {
	$output{'search-parameters'}->{'rarange'} = $rarange;
	$output{'search-parameters'}->{'decrange'} = $decrange;
    }

    my @pcals;

    my ($pos_ra, $pos_dec, $rturns, $sra_l, $sra_h, $sdec_l, $sdec_h);
    my ($low_ra, $high_ra, $low_dec, $high_dec);
    if ($mode eq "cone") {
	my @posels = split(/\,/, $position);
	$pos_ra = str2turn($posels[0], 'H');
	$pos_dec = str2turn($posels[1], 'D');
	my $sra = str2deg($posels[0], 'H');
	my $sdec = str2deg($posels[1], 'D');
	$sra_l = $sra - (1.5 * $radius);
	$sra_h = $sra + (1.5 * $radius);
	$sdec_l = $sdec - (1.5 * $radius);
	$sdec_h = $sdec + (1.5 * $radius);
	$rturns = $radius / 360;
    } elsif ($mode eq "slab") {
	$rarange =~ s/\s//g;
	$decrange =~ s/\s//g;
	($low_ra, $high_ra) = split(/\,/, $rarange);
	($low_dec, $high_dec) = split(/\,/, $decrange);
	$sra_l = $low_ra * 15;
	$sra_h = $high_ra * 15;
	$sdec_l = $low_dec;
	$sdec_h = $high_dec;
	# Convert everything to turns.
	$low_ra /= 24;
	$high_ra /= 24;
	$low_dec /= 360;
	$high_dec /= 360;
    }
    my @sql_args = ( $sdec_l, $sdec_h );
    if ($sra_l < 0) {
	push @sql_args, ($sra_l + 360);
	push @sql_args, 360;
	push @sql_args, 0;
	push @sql_args, $sra_h;
    } elsif ($sra_h > 360) {
	push @sql_args, $sra_l;
	push @sql_args, 360;
	push @sql_args, 0;
	push @sql_args, ($sra_h - 360);
    } else {
	if ($sra_h < $sra_l) {
	    push @sql_args, $sra_l;
	    push @sql_args, 360;
	    push @sql_args, 0;
	    push @sql_args, $sra_h;
	} else {
	    push @sql_args, $sra_l;
	    push @sql_args, $sra_h;
	    push @sql_args, $sra_l;
	    push @sql_args, $sra_h;
	}
    }
    my @cals;
    if ($scheduler_mode == 1 && $flux_limit_band eq "16cm") {
	@cals = CalDB::Calibrator->search_scheduler_position_16cm(@sql_args);
    } elsif ($scheduler_mode == 1 && $flux_limit_band eq "4cm") {
	@cals = CalDB::Calibrator->search_scheduler_position_4cm(@sql_args);
    } elsif ($scheduler_mode == 1 && $flux_limit_band eq "15mm") {
	@cals = CalDB::Calibrator->search_scheduler_position_15mm(@sql_args);
    } elsif ($scheduler_mode == 1 && $flux_limit_band eq "7mm") {
	@cals = CalDB::Calibrator->search_scheduler_position_7mm(@sql_args);
    } elsif ($scheduler_mode == 1 && $flux_limit_band eq "3mm") {
	@cals = CalDB::Calibrator->search_scheduler_position_3mm(@sql_args);
    } else {
#    if ($scheduler_mode == 0) {
	@cals = CalDB::Calibrator->search_position(@sql_args);
    }
    for (my $cc = 0; $cc <= $#cals; $cc++) {
	my $cal = $cals[$cc];
	# Get the calibrator's position.
	my $ra = str2turn($cal->rightascension, 'H');
	my $dec = str2turn($cal->declination, 'D');
	my $pos_diff = -100;
	if ($mode eq "cone") {
	    my $dec_diff = abs($pos_dec - $dec);
	    if ($dec_diff > $rturns) {
		# Separation too large.
		next;
	    }
	    # Apply a cosine correction.
	    my $avdec = ($dec + $pos_dec) / 2;
            my $ra_diff1 = ($ra - $pos_ra);
            my $ra_diff2 = (($ra - 1) - $pos_ra);
            my $ra_diff3 = ((1 + $ra) - $pos_ra);
            my $ura_diffa = (abs($ra_diff1) < abs($ra_diff2)) ? $ra_diff1 : $ra_diff2;
            my $ura_diff = (abs($ura_diffa) < abs($ra_diff3)) ? $ura_diffa : $ra_diff3;
	    my $ra_diff = $ura_diff * cos($avdec * 2 * 3.141592654);
	    $pos_diff = sqrt($ra_diff**2 + $dec_diff**2);
	    if ($pos_diff > $rturns) {
		next;
	    }
	} elsif ($mode eq "slab") {
	    my $ramatch = (($low_ra < $high_ra && $ra >= $low_ra && $ra <= $high_ra) ||
			   ($low_ra > $high_ra && ($ra >= $low_ra || $ra <= $high_ra)));
	    my $decmatch = ($dec >= $low_dec && $dec <= $high_dec);
	    if (!$ramatch || !$decmatch) {
		# Outside the area.
		next;
	    }
	}
	# Find all the measurements for this source.
	my @fluxdensities = split(/\,/, $cal->fluxdensities);
	my @fd_bands = split(/\,/, $cal->fluxdensities_bands);
	my @fd_meas = split(/\,/, $cal->measids);
	my @fd_coeffs;
	if ($scheduler_mode == 1) {
	    @fd_coeffs = split(/\//, $cal->fluxdensities_coeffs);
	}
	my %tres = (
	    'source_name' => $cal->name,
	    'rightascension' => $cal->rightascension,
	    'declination' => $cal->declination,
	    'flux_densities' => {}
	    );
	if ($mode eq "cone") {
	    $tres{'angular_distance'} = $pos_diff;
	}
	my @bands = ( '16cm', '4cm', '15mm', '7mm', '3mm' );
	for (my $i = 0; $i <= $#fluxdensities; $i++) {
	    $tres{'flux_densities'}->{$fd_bands[$i]} = {
		'flux_density' => $fluxdensities[$i],
		'measurement' => $fd_meas[$i],
		'flux_coeffs' => 0
	    };
	    if ($scheduler_mode == 1) {
		$tres{'flux_densities'}->{$fd_bands[$i]}->{'flux_coeffs'} = $fd_coeffs[$i];
	    }
	}
	my @bandsfound = keys %{$tres{'flux_densities'}};
	if ($allow_no_measurements == 0) {
	    if (($#bandsfound < 0) ||
		(defined $flux_limit_band &&
		 !defined $tres{'flux_densities'}->{$flux_limit_band})) {
		# We need to have at least one measurement to continue,
		# and potentially in a particular band.
		next;
	    }
	}
	if (defined $flux_limit_band &&
	    !defined $tres{'flux_densities'}->{$flux_limit_band}) {
	    next;
	} else {
	    if (defined $flux_limit_band &&
		defined $flux_limit &&
		$tres{'flux_densities'}->{$flux_limit_band}->{'flux_density'} < 
		$flux_limit) {
		next;
	    }
	    my %matchobj = (
		'name' => $cal->name,
		'rightascension' => $cal->rightascension,
		'declination' => $cal->declination,
		'flux_densities' => []
		);
	    if ($mode eq "cone") {
		$matchobj{'angular_distance'} = $tres{'angular_distance'};
	    }
	    for my $b (keys %{$tres{'flux_densities'}}) {
		push @{$matchobj{'flux_densities'}}, {
		    'bandname' => $b,
		    'frequency' => $tres{'flux_densities'}->{$b}->{'fd_frequency'},
		    'measurement' => $tres{'flux_densities'}->{$b}->{'measurement'},
		    'flux_coeffs' => $tres{'flux_densities'}->{$b}->{'flux_coeffs'},
		    'flux_density' => sprintf "%.3f", 
		    ($tres{'flux_densities'}->{$b}->{'flux_density'})
		};
	    }
	    push @{$output{'matches'}}, \%matchobj;
	}
    }
    
    return %output;
}

sub get_band_uvpoints {
    my $source = shift;
    my $band = shift;
    $source = lc $source;
    $band = lc $band;
    
    # Get the 5 most recent uv points for the specified source
    # in the specified band.
    my $measurements = CalDB::Measurement->search(
	'source_name' => $source,
	'frequency_band' => $band,
	'public' => 1,
	{ 'order_by' => 'observation_mjd_start DESC LIMIT 5' });
    my %output = ( 
	'source_name' => $source,
	'frequency_band' => $band,
	'uv_points' => [] );
    while (my $m = $measurements->next) {
	my @fd = $m->fluxdensities();
	my @uv = $fd[0]->uvpoints();
	for (my $i=0; $i<=$#uv; $i++) {
	    push @{$output{'uv_points'}},
	    { 'uv' => $uv[$i]->uvdistance_bin_centre,
	      'amp' => $uv[$i]->uvdistance_residual_amplitude };
	}
    }

    return %output;
}

sub get_band_timeseries {
    my $source = shift;
    my $band = shift;
    $source = lc $source;
    $band = lc $band;

    # Get all the flux models from the specified source
    # in the specified band and return them with the
    # time at which they were observed.
    my %output = (
	'source_name' => $source,
	'frequency_band' => $band,
	'time_series' => []
	);

    my $meas_iterator = CalDB::Measurement->search(
	'source_name' => $source,
	'frequency_band' => $band,
	'public' => 1
	);
    while (my $meas = $meas_iterator->next) {
	my $obs_mjd = ($meas->observation_mjd_start +
		       $meas->observation_mjd_end) / 2;
	my $flux_iterator = $meas->fluxdensities();
	while (my $flux = $flux_iterator->next) {
	    my @cs = split(/\,/, $flux->fluxdensity_fit_coeff);
	    push @{$output{'time_series'}}, {
		'observation_mjd' => $obs_mjd,
		'fluxdensity_coefficients' => \@cs,
		'fluxdensity_scatter' => $flux->fluxdensity_fit_scatter
	    };
	}
    }

    return %output;
}

sub get_band_quality {
    my $source = shift;
    my $band = shift;
    $source = lc $source;
    $band = lc $band;

    # Get the latest data for the specified source in
    # the specified band, and for all array sizes.
    my @arraysizes = ( '6km', '1.5km', '750m', '375m' );
    my @arrays = ( [ '6A', '6B', '6C', '6D' ],
		   [ '1.5A', '1.5B', '1.5C', '1.5D' ],
		   [ '750A', '750B', '750C', '750D' ],
		   [ 'EW367', 'EW352', 'H214', 'H168',
		     'H75', 'EW214', 'NS214' ] );

    my %output = (
	'source_name' => $source,
	'frequency_band' => $band
	);

    for (my $i=0; $i<=$#arraysizes; $i++) {
	my $sql = "";
	for (my $j=0; $j<=$#{$arrays[$i]}; $j++) {
	    if ($j > 0) {
		$sql .= "OR ";
	    }
	    $sql .= "array LIKE '".$arrays[$i]->[$j]."%' ";
	}
	$sql .= "ORDER BY mjd_start DESC";
#	print $sql."\n";
	my $latest_measurement = CalDB::Epoch->retrieve_from_sql($sql);
	my $f = 0;
	my $mit;
	while ($f == 0 &&
	       ($mit = $latest_measurement->next)) {
	    my $srcit = $mit->measurements('source_name' => $source,
					   'frequency_band' => $band,
					   'public' => 1);
	    if (my $src = $srcit->next) {
		$f = 1;
		$output{$arraysizes[$i]} = { 'defect' => -100,
					     'closure_phase' => -100 };
		my @fd = $src->fluxdensities();
		my $vec = $fd[0]->fluxdensity_vector_averaged;
		my $sca = $fd[0]->fluxdensity_scalar_averaged;
		$output{$arraysizes[$i]}->{'defect'} = (($sca / $vec) - 1) * 100;
		my @fq = $src->frequencies();
		my @clo = $fq[0]->closurephases();
		$output{$arraysizes[$i]}->{'closure_phase'} =
		    $clo[0]->closure_phase_average;
	    }
	}
    }

    return %output;
}

sub get_band_fluxdensity {
    my $source = shift;
    my $band = shift;
    $source = lc $source;
    $band = lc $band;

    # Get the latest flux density model fit for the
    # specified source in the specified band.
    my $latest_measurement = CalDB::Measurement->search(
	'source_name' => $source,
	'frequency_band' => $band,
	'public' => 1,
	{ 'order_by' => 'observation_mjd_start DESC' });
    my $latest_measid = $latest_measurement->next;
    my @fluxes = $latest_measid->fluxdensities();
    my %output = ( 'fluxdensity_coefficients' => [],
		   'fluxdensity_scatter' => 0,
		   'source_name' => $source,
		   'frequency_band' => $band );
    my @cs = split(/\,/, $fluxes[0]->fluxdensity_fit_coeff);
    $output{'fluxdensity_coefficients'} = \@cs;
    $output{'fluxdensity_scatter'} = $fluxes[0]->fluxdensity_fit_scatter;
    $output{'observation_mjd'} = ($latest_measid->observation_mjd_start +
				  $latest_measid->observation_mjd_end) / 2;

    return %output;
}

sub get_recent_changes {
    my $nc = shift;

    # Get a list of the most recent changes to the
    # calibrator database.
#    my $sql = "title != '' ORDER BY change_time DESC";
#    if (defined $nc) {
#	$sql .= " LIMIT ".$nc;
#    }
#    my @changes = CalDB::Change->retrieve_from_sql($sql);
    my @changes = CalDB::Change->search_public();

    my %output = ( 'changes' => [] );
    for (my $i=0; $i<=$#changes; $i++) {
	my $epochid = ($changes[$i]->epoch_id) ?
	    $changes[$i]->epoch_id->epoch_id : 'null';
	my $calid = ($changes[$i]->cal_id) ?
	    $changes[$i]->cal_id->cal_id : 'null';
	if ($calid ne 'null') {
	    # Find out the calibrator name.
	    my $calref = CalDB::Calibrator->retrieve($calid);
	    $calid = $calref->name;
	}
	push @{$output{'changes'}}, {
	    'time' => $changes[$i]->change_time,
	    'epoch_id' => $epochid,
	    'cal_id' => $calid,
	    'change_id' => $changes[$i]->change_id,
	    'title' => $changes[$i]->title,
	    'description' => $changes[$i]->description
	};
    }

    return %output;
}

sub get_epoch_list {
    my $optionsref = shift;

    # Get a list of all the epochs we have in the database.
    my @epochs = CalDB::Epoch->retrieve_all;

    my %output = ( 'epochs' => [] );
    for (my $i=0; $i<=$#epochs; $i++) {
	if (($optionsref && $optionsref->{'all'}) ||
	    $epochs[$i]->public == 1) {
	    if (!$optionsref || !$optionsref->{'project'} ||
		$optionsref->{'project'} eq $epochs[$i]->project_code) {
		push @{$output{'epochs'}}, {
		    'epoch_id' => $epochs[$i]->epoch_id,
		    'project_code' => $epochs[$i]->project_code,
		    'array' => $epochs[$i]->array,
		    'mjd_start' => $epochs[$i]->mjd_start,
		    'mjd_end' => $epochs[$i]->mjd_end
		};
	    }
	}
    }
    
    return %output;
}

sub get_epoch_summary {
    my $epoch_id = shift;

    # Determine the number of sources that were observed, and
    # the different bands.
    my %output = ( 
	'epoch_id' => $epoch_id,
	'nsources' => 0,
	'bands' => {} 
	);
    # Check first if a summary is already present.
    my $epoch = CalDB::Epoch->retrieve($epoch_id);
    if ($epoch) {
	my @summaries = $epoch->summaries();
	for (my $i=0; $i<=$#summaries; $i++) {
	    if ($summaries[$i]->frequency_band eq 'all') {
		$output{'nsources'} = $summaries[$i]->n_sources;
	    } else {
		$output{'bands'}->{$summaries[$i]->frequency_band} = 1;
	    }
	}
	if ($#summaries > 0) {
	    return %output;
	}
    }
    my %sources;
    my $meas_iterator = CalDB::Measurement->search(
	'epoch_id' => $epoch_id
	);
    while(my $meas = $meas_iterator->next) {
	if (!defined $sources{$meas->source_name}) {
	    $sources{$meas->source_name} = 1;
	}
	if (!defined $output{'bands'}->{$meas->frequency_band}) {
	    $output{'bands'}->{$meas->frequency_band} = 1;
	}
    }

    my @k = keys %sources;
    $output{'nsources'} = ($#k + 1);

    return %output;
}

sub get_epoch_data {
    my $epoch_id = shift;
    my $optionsref = shift;

    # Get a list of all the sources observed in an epoch,
    # and return their flux density fits for each band.
    my %output = ( 'epoch_id' => $epoch_id,
		   'sources' => {} );
    my $pubr = 1;
    if ($optionsref && $optionsref->{'all'} == 1) {
	$pubr = 0;
    }

    my $meas_iterator = CalDB::Measurement->search_data($epoch_id, $pubr);
    while (my $meas = $meas_iterator->next) {
	my @cs = split(/\,/, $meas->fluxdensity_fit_coeff);
	if (!defined $output{'sources'}->{$meas->source_name}) {
	    $output{'sources'}->{$meas->source_name} = {};
	}
	my $bnd = $meas->frequency_band;
	if ($meas->self_calibrated == 0) {
	    $bnd .= "-uncal";
	}
	$output{'sources'}->{$meas->source_name}->{$bnd} = {
	    'mjd_start' => $meas->observation_mjd_start,
	    'integration' => $meas->observation_mjd_integration,
	    'fluxdensity_coefficients' => \@cs,
	    'fluxdensity_scatter' => $meas->fluxdensity_fit_scatter,
	    'meas_id' => $meas->meas_id,
	    'fluxdensity_kstest_d' => $meas->kstest_d,
	    'fluxdensity_kstest_prob' => $meas->kstest_prob,
	    'fluxdensity_reduced_chisquare' => $meas->reduced_chisquare,
	    'self_calibrated' => $meas->self_calibrated
	};
    }

    return %output;
}

sub get_calibrator_names {
    # Get a list of all the calibrator names.
    # We make this available to make it easy to make an autocomplete
    # box on the web page.
    
    my $caliterator = CalDB::Calibrator->retrieve_all;
    my %output = ( 'names' => [] );

    while (my $cal = $caliterator->next) {
	push @{$output{'names'}}, $cal->name;
    }

    return %output;
}

sub get_information {
    my $source = shift;

    # Get information about the named source.
    my @calinfo = CalDB::Calibrator->search('name' => lc($source));

    my %output;
    if ($#calinfo == 0) {
	$output{'name'} = $calinfo[0]->name;
	$output{'rightascension'} = $calinfo[0]->rightascension;
	$output{'declination'} = $calinfo[0]->declination;
	$output{'notes'} = &txt2html($calinfo[0]->notes);
	$output{'catalogue'} = $calinfo[0]->catalogue;
	$output{'info'} = $calinfo[0]->info;
	$output{'vla_text'} = $calinfo[0]->vla_text;
	$output{'vla_text'} =~ s/manual/manual-obsolete/g;
	if ($calinfo[0]->info && $quality{$calinfo[0]->info}) {
	    $output{'quality'} = $quality{$calinfo[0]->info};
	} elsif ($calinfo[0]->info ne '') {
	    my $info=$calinfo[0]->info;
	    my ($post) = $info =~ m{\((\S+?)\)};
	    my ($pre) = $info =~ m{([^\(]+)};
	    $info = "[$pre]";
	    if($post){ 
		$post =~ s/x/&#963;/; 
		$post =~ s/</ &lt; /; 
		$post =~ s/>/ &gt; /; 
		$info = "$post arcsec $info";
	    }
	    $output{'quality'} = $info;
	}
    } elsif ($#calinfo < 0) {
	# The source hasn't got info in the calibrator list, but
	# we'll get information from the latest time it was observed.
	my $calit = CalDB::Measurement->search(
	    'source_name' => $source,
	    'public' => 1,
	    { 'order_by' => 'observation_mjd_start DESC' } );
	my $cal = $calit->next;
	if ($cal) {
	    $output{'name'} = $cal->source_name;
	    $output{'rightascension'} = $cal->rightascension;
	    $output{'declination'} = $cal->declination;
	    my ($d,$m,$y,$u) = mjd2cal($cal->observation_mjd_start);
	    $output{'notes'} = sprintf 
		"This source is not in the calibrator database. ".
		"The information presented here is from an observation on ".
		"%4d-%3s-%02d UTC.", $y, $months[$m - 1], $d;
	    $output{'catalogue'} = "none";
	    $output{'info'} = "N/A";
	    $output{'vla_text'} = "";
	}
    }

    return %output;
}

sub txt2html {
    my $txt = shift;
    
    $txt =~ s/\n/\<br\/\>/g;

    return $txt;
}

sub bibcode{
  my $mybib = shift;

  return "http://adsabs.harvard.edu/cgi-bin/nph-data_query?bibcode=".$mybib.
      "&db_key=AST&link_type=ABSTRACT";
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

sub freq2band {
    my $freq = shift;

    if ($freq =~ /\,/) {
	my @fs = split(/\,/, $freq);
	$freq = $fs[0];
    }

    if ($freq < 4000) {
	return "16cm";
    } elsif ($freq < 12000) {
	return "4cm";
    } elsif ($freq < 30000) {
	return "15mm";
    } elsif ($freq < 60000) {
	return "7mm";
    } else {
	return "3mm";
    }
}
