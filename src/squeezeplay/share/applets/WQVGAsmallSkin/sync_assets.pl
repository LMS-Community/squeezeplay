#!/usr/bin/perl

#
# Script to help intelligently copy and update png files from Fab4Skin assets area to skin
#
# 1. removes all png files from images/ directory, except those in the directory UNOFFICIAL and directory IconsResized
# 2. copies every png file from assets/WQVGAsmallSkin/images area to correct path in images/ directory
# 3. runs svk status, uses output to create a shell script for doing the necessary svk commands
#
# bklaas 03.09

use strict;
use File::Next;
use File::Basename;
use File::Copy;

my $d = {
	assets => {
		skinDir => 'images/',
		assetDir => '../../../../../assets/Fab4Skin/images/',
	},
	clocks => {
		skinDir => 'images/Clocks',
		assetDir => '../../../../../assets/Fab4Skin/Screensavers/Clocks',
	},
};

my $images = get_assets($d->{assets}{skinDir});
my $assets = get_assets($d->{assets}{assetDir});
my $clocks = get_assets($d->{clocks}{assetDir});

# remove existing images
remove_images($images);

# copy assets
copy_assets($assets, 'assets');

# copy clock assets
copy_assets($clocks, 'clocks');

# create svk file
create_svk_file();

# handle special assets
my @commands = ( 
	"cp ../../../../../assets/Fab4Skin/Splash_Screen/bootloader_100.png ../../jive/splash.png",
	"svk status ../../jive/splash.png 2>&1 ",
);

for my $command (@commands) {
	open(STATUS, "$command |");
	while(<STATUS>) {
		print "SPECIAL: $_";
	}
	close(STATUS);
}

sub create_svk_file {
	my $prog = "svk status " . $d->{assets}{skinDir};
	my @commands = ();
	open(PROG, "$prog |");
	while(<PROG>) {
		s/^\?\s+/svk add /;
		s/^\!\s+/svk remove /;
		if (/^svk/) {
			push @commands, $_;
		}
	}
	close(PROG);

	if ($commands[0]) {
		print STDOUT "-------------\n";
		open(OUT, ">svkUpdate.bash");
		print OUT "#!/bin/bash\n\n";
		print STDOUT "#!/bin/bash\n\n";
		for (@commands) {
			print OUT $_;
			print STDOUT $_;
		}
		close(OUT);
	}
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
	my $key    = shift;
	for my $image (@$assets) {
		my $newImage = $image;
		$newImage =~ s/$d->{$key}{assetDir}/$d->{$key}{skinDir}/;
		copy($image, $newImage);
	}
}


