#!/usr/bin/perl
# This program:
# 1) Gets the latest Jive FW
# 2) Runs the smoke test on it
# 3) Checks to see if it passes well enough
# 4) Uploads it

use strict;
use warnings;
use LWP::UserAgent;

my $debug = 1;
my $url = 'https://eng.slimdevices.com/images/fab4/';

my $response; # Web page object NOT raw html
my $content; # web html goes in here

my $target_version; # product version I am trying to test
my @product_versions; # List of product versions
my $product_version; # version I'm currently working on
my $latest_version; # latest version found

my $target_build; # build I am trying to test
my @builds_avail; #The dates listed on the site
my $build; # the build I'm currently working on
my $latest_build; # the latest build found

my @filelist; # List of files found in the build directory
my $filename; # current working file
my $strpos; # position of a string in an array

my $ua = LWP::UserAgent->new; # Create UserAgent browser object

# If there're no arguments given, assume you want to run on the latest build
if (! defined($ARGV[0])) {
	$ARGV[0] = "latest";
	$ARGV[1] = "latest";
}

if (! defined($ARGV[1])) {
	$ARGV[1] = "latest";
}

$target_version = $ARGV[0];
$target_build = $ARGV[1];

debug ("looking for version $target_version, build $target_build");

if ($target_version =~ "help") {
	print "getnrun [version] [build]\n\n";
	print "https://eng.slimdevices.com/images/fab4/ for more info\n";
	print "If no arguments are entered, the default is 'most recent'.\n";
	exit 1;
}

@product_versions = dir_from_url($url);
# debug ("Here's the versions I got back: @product_versions");

@product_versions = sort(@product_versions);

$latest_version = $product_versions[-1]; # get the last element of the array

debug ("Latest product version found: $latest_version");

if ($target_version eq "latest") {
	$url = $url.$latest_version;
	$target_version = $latest_version;
}
else {
	$url = $url.$target_version."/";
}


$strpos = find_str_in_array($target_version, @product_versions);
# debug ("Found $target_version at $strpos");
if ($strpos == 0) {
	print "Couldn't find version $target_version at $url\n";
	exit 1;
}

# Now let's see what's in the directory for the version specified
@builds_avail = dir_from_url($url);
# debug ("Retrieved: @builds_avail");
@builds_avail = sort(@builds_avail);
$latest_build = $builds_avail[-1]; # get the last element of the array
# debug ("Latest build found: $latest_build");

# Now let's see what's in the directory for the build specified
if ($target_build eq "latest") {
	$url = $url.$latest_build;
}
else {
	$url = $url.$target_build;
}

$strpos = find_str_in_array($target_build, @builds_avail);
# debug ("Found $target_build at $strpos");
if ($strpos == 0) {
	print "Couldn't find build $target_build at $url\n";
	exit 1;
}

debug ("Getting dir listing for $url");
@filelist = dir_from_url($url);
debug ("Retrieved: @filelist");

# Download all the files (.bin .md5 .sha)
# Check that sha sum matches
# run the smoke test 
# Check to see if the smoke test important tests passed (last step)
# Upload three files if they pass
 
sub debug {
	print "$_[0]\n";
}

sub dir_from_url {
	# Takes a url, returns an array of files listed there

	my $url = $_[0];
	my $content;
	my @filenames; # list of found filenames 
	my $filename; 
	debug ("Getting $url");
	my $response = $ua->get( $url );

	$response->is_success or
		die "Is the network or server down? Failed to get $url: ", $response->status_line;

	$content = $response->as_string; # turn it into a string
	# debug ("Retrieved: $content");

	# split the html into substrings around the opening tag
	@filenames = split(/<a href="/, $content); 

	shift(@filenames); # first element does not have a valid filename
	shift(@filenames); # second element does not have a valid filename
	shift(@filenames); # third element does not have a valid filename
	shift(@filenames); # fourth element does not have a valid filename
	shift(@filenames); # fifth element does not have a valid filename

	# TODO clean this up
	foreach $filename (@filenames) {
		$filename =~ s/">.+//; # Kill everything after the ">
		$filename =~ s/\n.+//; # Delete everything after any newline
		$filename =~ s/.+<td>//; #Kill everything up to the <td>
		$filename =~ s/<\/table>\n.+\n<\/body>.+//; #More stuff on the end
		$filename =~ s/\n//; #make sure I got all the newlines
		# $filename = "+".$filename."+";

	}
	# debug("filename list?:@filenames");
	return @filenames;
}

sub find_str_in_array {
	# debug ("find_str_in_array operating on @_");
	(my $string, my @array) = @_;
	my $count = 0;
	# debug ("Checking if $string is defined");
	if (defined $string) {
		# debug ("Apparently yes");
		foreach (@array) {
			# debug ("Searching for $string in $_");
			if ($_ =~ /$string/) {
				return $count;
			}
			$count++;
		}
	}
}
