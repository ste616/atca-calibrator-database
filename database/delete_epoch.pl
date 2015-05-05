#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;
use Data::Dumper;

# Delete an epoch from the database.
my $delepoch = $ARGV[0];

print "Delete epoch $delepoch, are you sure? [N/y]\n";
chomp(my $a = <STDIN>);
if ($a eq 'Y' || $a eq 'y') {
    print "OK. Deleting epoch $delepoch...\n";
    # Get the epoch.
    my $epoch = CalDB::Epoch->retrieve($delepoch);
    if ($epoch) {
	# Delete the epoch and all objects attached to it.
	$epoch->delete;
	# Delete the change log for that epoch.
	CalDB::Change->search(epoch_id => $delepoch)->delete_all;
    }
}
