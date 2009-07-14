#!/usr/bin/perl

#
# Script to help intelligently copy and update png files from QVGASkin assets area to skin
#
# 1. removes all png files from images/ directory, except those in the directory UNOFFICIAL and directory IconsResized
# 2. copies every png file from assets/WQVGAsmallSkin/images area to correct path in images/ directory
# 3. runs svk status, uses output to create a shell script for doing the necessary svk commands
#
# bklaas 03.09

use strict;
use File::Next;
use File::Basename;
use File::Path;
use File::Copy;

use Data::Dump;

my $d = {
	# shared assets
	assets => {
		skinDir => 'images/',
		assetDir => '../../../../../assets/QVGAskin',
		omit     => [ 'Landscape', 'Portrait' ],
	},
	# assets specific to QVGAlandscapeSkin
	landscapeAssets => {
		skinDir => '../QVGAlandscapeSkin/images',
		assetDir => '../../../../../assets/QVGAskin/Landscape/images',
	},
	# assets specific to QVGAportraitSkin
	portraitAssets => {
		skinDir => '../QVGAportraitSkin/images',
		assetDir => '../../../../../assets/QVGAskin/Portrait/images',
	},
	# clocks go to the Clocks subdir of each skin
	landscapeClocks => {
		assetDir => '../../../../../assets/QVGASkin/Landscape/Screensavers/Clocks',
		skinDir => '../QVGAlandscapeSkin/images/Clocks',
	},
	portraitClocks => {
		assetDir => '../../../../../assets/QVGASkin/Portrait/Screensavers/Clocks',
		skinDir => '../QVGAportraitSkin/images/Clocks',
	},
	# copy landscape wallpaper to squeezeplay_baby
	landscapeWallpaper => {
		assetDir => '../../../../../assets/QVGAskin/Landscape/Wallpaper',
		skinDir => '../../../../squeezeplay_baby/share/applets/SetupWallpaper/wallpaper',
	},
	# copy landscape wallpaper to squeezeplay_desktop
	landscapeWallpaperToDesktop => {
		assetDir => '../../../../../assets/QVGAskin/Landscape/Wallpaper',
		skinDir => '../../../../squeezeplay_desktop/share/applets/SetupWallpaper/wallpaper',
	},
	# copy portrait wallpaper to squeezeplay_jive
	portraitWallpaper => {
		assetDir => '../../../../../assets/QVGAskin/Portrait/Wallpaper',
		skinDir => '../../../../squeezeplay_jive/share/applets/SetupWallpaper/wallpaper',
	},
	# copy portrait wallpaper to squeezeplay_desktop
	portraitWallpaperToDesktop => {
		assetDir => '../../../../../assets/QVGAskin/Portrait/Wallpaper',
		skinDir => '../../../../squeezeplay_desktop/share/applets/SetupWallpaper/wallpaper',
	},
};

message("Getting existing assets");

my $images = get_assets($d->{assets}{skinDir});
my $landscapeImages = get_assets($d->{landscapeAssets}{skinDir});
my $portraitImages = get_assets($d->{portraitAssets}{skinDir});
#
message("Getting Noah's assets");

my $assets = get_assets($d->{assets}{assetDir}, $d->{assets}{omit});
my $landscapeAssets = get_assets($d->{landscapeAssets}{assetDir});
my $portraitAssets  = get_assets($d->{portraitAssets}{assetDir});

# clocks?
my $landscapeClocks = get_assets($d->{landscapeClocks}{assetDir});
my $portraitClocks = get_assets($d->{portraitClocks}{assetDir});

# handle wallpapers?
my $landscapeWallpaper = get_assets($d->{landscapeWallpaper}{assetDir});
my $portraitWallpaper = get_assets($d->{portraitWallpaper}{assetDir});

message("Removing existing assets");

# remove existing images
remove_images($images);
remove_images($landscapeImages);
remove_images($portraitImages);

message("Copying assets");

# copy assets
copy_assets($assets, 'assets');
copy_assets($landscapeAssets, 'landscapeAssets');
copy_assets($portraitAssets, 'portraitAssets');

# copy clock assets
copy_assets($landscapeClocks, 'landscapeClocks');
copy_assets($portraitClocks, 'portraitClocks');

# copy wallpaper assets
copy_assets($landscapeWallpaper, 'landscapeWallpaper');
copy_assets($landscapeWallpaper, 'landscapeWallpaperToDesktop');
copy_assets($portraitWallpaper, 'portraitWallpaper');
copy_assets($portraitWallpaper, 'portraitWallpaperToDesktop');

# create svk file
message("creating svkUpdate.bash to be run separately");
my @keys = keys %$d;
create_svk_file(\@keys);


sub message {
	my $message = shift;
	print "!-----------------------------------------!\n";
	print "$message\n";
}

sub create_svk_file {

	my $keys = shift;
	my @commands = ();
	for my $key (@$keys) {
		my $prog = "svk status " . $d->{$key}{skinDir};
		open(PROG, "$prog |");
		while(<PROG>) {
			s/^\?\s+/svk add /;
			s/^\!\s+/svk remove /;
			if (/^svk/) {
				push @commands, $_;
			}
		}
		close(PROG);
	}

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

# get all png files from 
sub get_assets {
	my $path = shift;
	my $omit = shift || undef;
	my $files = File::Next::files($path);
	my @return;
	while ( defined ( my $file = $files->() ) ) {
		my $skip = 0;
		if ($omit) {
			for my $omitMe (@$omit) {
				if ($file =~ /\/$omitMe\//) {
					$skip = 1;
					last;
				}
			}
		}
		if ($skip) {
			next;
		}

		# don't get Landscape or Portrait images for main asset area
		if ($path eq $d->{assets}{skinDir} && ($file =~ /\/Landscape\// || $file =~ /\/Portrait\//) ) {
			next;
		}

		# only get png/jpg/gif images
		if ( ($file =~ /\.png$/ || $file =~ /\/jpg$/i || $file =~ /\/gif/i ) &&  
			$file !~ /UNOFFICIAL/ && $file !~ /IconsResized/  ) {
				push @return, $file 
		}
			
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
		my $dirname = dirname($newImage);
		if (! -d $dirname) {
			mkpath([ $dirname ], 1, 0755);
		}
		copy($image, $newImage);
	}
}


