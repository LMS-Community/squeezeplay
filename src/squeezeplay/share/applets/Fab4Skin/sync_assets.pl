#!/usr/bin/perl

#
# Script to help intelligently copy and update png files from Fab4Skin assets area to skin
#
# 1. removes all png files from images/ directory, except those in the directory UNOFFICIAL and directory IconsResized
# 2. copies every png file from assets/Fab4Skin/images area to correct path in images/ directory
# 3. runs svk status, uses output to create a shell script for doing the necessary svk commands
#
# bklaas 03.09

use strict;
use File::Next;
use File::Basename;
use File::Copy;

my $skinDir = "images/";
my $assetDir = "../../../../../assets/Fab4Skin/images/";

my $images = get_assets($skinDir);
my $assets = get_assets($assetDir);

# remove existing images
remove_images($images);
# copy assets
copy_assets($assets);
# create svk file
create_svk_file();

sub create_svk_file {
	my $prog = "svk status $skinDir";
	open(OUT, ">svkUpdate.bash");
	open(PROG, "$prog |");
	print OUT "#!/bin/bash\n\n";
	while(<PROG>) {
		s/^\?\s+/svk add /;
		s/^\!\s+/svk remove /;
		if (/^svk/) {
			print OUT $_;
		}
	}
	close(OUT);
	close(PROG);
}

sub get_assets {
	my $path = shift;
	my $files = File::Next::files($path);
	my @return;
	while ( defined ( my $file = $files->() ) ) {
		push @return, $file if $file =~ /\.png$/ &&  $file !~ /UNOFFICIAL/ && $file !~ /IconsResized/ ;
	}
	return \@return;
}

sub remove_images {
	my $images = shift;
	for my $image (@$images) {
		my $success = unlink $image;
		if ($success != 1) {
			print STDERR "There was a problem removing $image\n";
		}
	}
}

sub copy_assets {
	my $assets = shift;
	for my $image (@$assets) {
		my $newImage = $image;
		$newImage =~ s/$assetDir/$skinDir/;
		copy($image, $newImage);
	}
}


