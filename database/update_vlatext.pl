#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;
use Data::Dumper;

use strict; use warnings;

# Read in the new VLA calibrator HTML file.
open(V, "vla_list.html.new");
my @vla_lines;
while(<V>) {
    chomp;
    push @vla_lines, $_;
}
close(V);

# Get a list of VLA calibrators.
my $caliterator = CalDB::Calibrator->search(
    'catalogue' => 'vla'
    );
while (my $cal = $caliterator->next) {
    print "VLA calibrator ".$cal->name."\n";
    my @a;
    my $found = 0;
    my $n = $cal->name;
    $n =~ s/\+/\\\+/;
    for (my $i=0; $i<=$#vla_lines; $i++) {
	my $line = $vla_lines[$i];
	$line =~ s/^\s*//;
	if ($line eq '') {
	    if ($found == 0) {
		@a = ();
	    } else {
		last;
	    }
	} else {
	    push @a, $vla_lines[$i];
	    if ($vla_lines[$i] =~ /$n\s+B1950/) {
		$found = 1;
	    }
	}
    }
    if ($found == 1) {
	my $ntext = "";
	for (my $i=0; $i<=$#a; $i++) {
#	print $a[$i]."\n";
	    if ($i > 0) {
		$ntext .= "\n";
	    }
	    $ntext .= $a[$i];
	}
	print $ntext;
	$cal->vla_text($ntext);
	$cal->update;
    }
}

