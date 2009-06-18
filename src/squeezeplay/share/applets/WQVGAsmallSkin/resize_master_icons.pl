#!/usr/bin/perl

#
# Script to take assets from squeezeplay/assets/MasterIcons directory and resize them into correct size(s)
#
# 1. runs a convert command to each file from @iconConvertList from the MasterIcons file to correct w x h dimensions for the skin (or skins), saves output to a temp folder
# 2. does a diff between the new file and the one currently in iconsResized with same name
# 3. if different (or new), copies it into iconsResized
# 4. runs svk status, uses output to create a shell script for doing the necessary svk commands
#
# bklaas 03.09

use strict;
use File::Next;
use File::Basename;
use File::Copy;

my $resizedIconDir = "images/IconsResized";
my $assetDir = "../../../../../assets/MasterIcons";
my $convertCommand = "/opt/local/bin/convert";

# define skins and dimensions for each
my $resize = { 
		'touch'	=>	40,
		'remote' =>	64,
};


# only convert these icons
my @iconConvertList = (qw/ 
icon_settings_brightness.png
icon_settings_repeat.png
icon_settings_shuffle.png
icon_settings_sleep.png
icon_settings_screen.png
icon_settings_home.png
icon_settings_audio.png
icon_loading.png
icon_settings_plugin.png
icon_album_noart.png
icon_app_guide.png
icon_boom.png
icon_controller.png
icon_ethernet.png
icon_fab4.png
icon_internet_radio.png
icon_mymusic.png
icon_power_off2.png
icon_receiver.png
icon_region_americas.png
icon_region_other.png
icon_SB1n2.png
icon_SB3.png
icon_settings.png
icon_slimp3.png
icon_softsqueeze.png
icon_squeezeplay.png
icon_transporter.png
icon_wireless.png
icon_firmware_update.png
icon_verify.png
icon_restart.png
icon_playlist_save.png
icon_playlist_clear.png

icon_favorites.png
icon_sleep.png
icon_ml_years.png
icon_ml_search.png
icon_ml_random.png
icon_ml_playlist.png
icon_ml_new_music.png
icon_ml_genres.png
icon_ml_artist.png
icon_linein.png
icon_ml_folder.png
icon_ml_albums.png
icon_folder.png
icon_digital_inputs.png
icon_choose_player.png
icon_sync.png
icon_staffpicks.png
icon_nature_sounds.png
icon_alarm.png
icon_RSS.png
icon_power_off2.png
icon_blank.png

/);

my $special = {
"icon_firmware_update.png"	=>	{ touch	=> 100,	remote	=> 100 },
"icon_verify.png"		=>	{ touch	=> 100,	remote	=> 100 },
"icon_restart.png"		=>	{ touch	=> 100,	remote	=> 100 },
};

my $existingImages = get_assets($resizedIconDir);
remove_images($existingImages);

# convert the files
convert_files();

# create svk file
create_svk_file();

sub convert_files {
	#for my $file (sort keys %$assets) {
	for my $f (@iconConvertList) {
		my $file = $assetDir . "/" . $f;
		for my $skin (sort keys %$resize) {
			my $size = $resize->{$skin};
			if ($special->{$f}{$skin}) {
				print "SPECIAL: $f\t$special->{$f}{$skin}\n";
				$size = $special->{$f}{$skin};
			}
			my $basename = fileparse($file, qr/\.[^.]*/);
			my $filename = $resizedIconDir . "/" . $basename . "_" . $skin . ".png";
			my $resizeMe = "$convertCommand -geometry ${size}x${size} $file $filename";
			open(PROG, "$resizeMe |") or die "Could not run convert command: $!";
			print STDOUT "$resizeMe\n";
			while(<PROG>) {
			}
			close(PROG);
		}
	}
}

sub remove_images {
	my $images = shift;
	for my $image (keys %$images) {
		print "REMOVING $image\n";
		my $success = unlink $image;
		if ($success != 1) {
			print STDERR "There was a problem removing $image\n";
		}
	}
}

sub create_svk_file {
	my $prog = "svk status $resizedIconDir";
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
		open(OUT, ">svkUpdate.bash");
		print OUT "#!/bin/bash\n\n";
		for (@commands) {
			print OUT $_;
		}
	}
}

sub get_assets {
	my $path = shift;
	my $files = File::Next::files($path);
	my %return;
	while ( defined ( my $file = $files->() ) ) {
		my ($name,$dir,$suffix) = fileparse($file);
		if ($path eq $assetDir && $dir !~ /Apps/ && $dir !~ /Music_Library/) {
			$return{$file}++ if $file =~ /\.png$/;
		} elsif ($path ne $assetDir) {
			$return{$file}++ if $file =~ /\.png$/ && $file !~ /UNOFFICIAL/;
		}
	}
	return \%return;
}

sub copy_assets {
	my $assets = shift;
	for my $image (@$assets) {
		my $newImage = $image;
		$newImage =~ s/$assetDir/$resizedIconDir/;
		copy($image, $newImage);
	}
}
