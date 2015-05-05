#!/usr/bin/perl

use lib '/n/ste616/usr/lib/perl5/lib/perl5';
use CalDBkaputar;
use CalDB;
use Data::Dumper;

use strict; use warnings;

# Change some calibrator's position, update the notes and
# add a change log to the database.
my $calname = $ARGV[0];

# Try to find this calibrator.
my $cal_iterator = CalDB::Calibrator->search(
    'name' => $calname
    );
my $cal = $cal_iterator->next;
if (!$cal) {
    die "Cannot find calibrator ".$cal;
}

my $newra = $ARGV[1];
my $newdec = $ARGV[2];

my $oldra = $cal->rightascension;
my $olddec = $cal->declination;

print "This will change the position of ".$calname." from:\n";
print "R.A. / Dec. = ".$oldra." / ".$olddec."\n";
print " to:\n";
print "R.A. / Dec. = ".$newra." / ".$newdec."\n";

print "Are you sure you wish to continue? (y/N) ";
chomp(my $answer = <STDIN>);
if ($answer ne "y" && $answer ne "Y") {
    die "No permission to change position.";
}

print "Changing position...\n";

# Make a new change log.
my $change_title = "Position of ".$calname." changed.";
my $change_description = "The position of the calibrator ".$calname.
    " was changed from R.A.,Dec. = ".$oldra.",".$olddec." to ".
    "R.A.,Dec. = ".$newra.",".$newdec.".";
if ($ARGV[3]) {
    $change_description .= " ".$ARGV[3];
}
print "Change summary is as follows:\n";
print "Title: \"".$change_title."\"\n";
print "Description: \"".$change_description."\"\n";

# Update the notes.
my $calnotes = $cal->notes;
my @timenow = localtime(time);
my @months = ( 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
	       'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC' );
my $tstring = sprintf "%4d-%3s-%02d", ($timenow[5] + 1900),
    $months[$timenow[4]], $timenow[3];
if ($calnotes ne "") {
    $calnotes .= "<br>".$tstring.": ".$change_description;
} else {
    $calnotes = $tstring.": ".$change_description;
}
print $calnotes."\n";

print "Updating database with this information. Continue? (y/N)";
chomp(my $banswer = <STDIN>);
if ($banswer ne "y" && $banswer ne "Y") {
    die "No permission to update database.";
}

# Change the position and notes.
$cal->rightascension($newra);
$cal->declination($newdec);
$cal->notes($calnotes);
$cal->update;

my $change = CalDB::Change->insert(
    {
	'title' => $change_title,
	'description' => $change_description,
	'cal_id' => $cal->cal_id
    });

print "Database updated.\n";

exit;
