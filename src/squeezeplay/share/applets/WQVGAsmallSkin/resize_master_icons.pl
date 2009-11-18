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


my @iconConvertList = get_icon_list();

my $special = {
"icon_firmware_update.png"	=>	{ touch	=> 120,	remote	=> 120 },
"icon_verify.png"		=>	{ touch	=> 120,	remote	=> 120 },
"icon_restart.png"		=>	{ touch	=> 120,	remote	=> 120 },
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
		next unless -e $file;
		for my $skin (sort keys %$resize) {
			my $size = $resize->{$skin};
			if ($special->{$f}{$skin}) {
				print "SPECIAL: $f\t$special->{$f}{$skin}\n";
				$size = $special->{$f}{$skin};
			}
			my $basename = fileparse($file, qr/\.[^.]*/);
			my $filename = $resizedIconDir . "/" . $basename . "_" . $skin . ".png";
			resize_me($file, $filename, $size);
		}
	}

	# special case, no album artwork for now playing screen. we still want the thumb size one for lists,
        # but also a larger one as a default artwork for NP screen
        my $source = $assetDir . "/" . "icon_album_noart.png";
	for my $size (143, 180) {
	        my $dest   = $resizedIconDir . "/" . "icon_album_noart_" . $size . ".png";
	        resize_me($source, $dest, $size);
	}
        my $source = $assetDir . "/" . "icon_linein.png";
        my $dest   = $resizedIconDir . "/" . "icon_linein_134.png";
        resize_me($source, $dest, 134);
}

sub resize_me {
	my ($file, $filename, $size) = @_;
	my $resizeMe = "$convertCommand -geometry ${size}x${size} $file $filename";
	open(PROG, "$resizeMe |") or die "Could not run convert command: $!";
	print STDOUT "$resizeMe\n";
	while(<PROG>) { }
	close(PROG);
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
		open(OUT, ">svkResizedIcons.bash");
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

sub get_icon_list {
	my $file = "masterIconList.txt";
	my @return;

	open(IN, "<$file") or die "$!";
	while(<IN>) {
		chomp;
		next if /^#/ || /^$/;
		push @return, $_;
	}
	close(IN);
	return @return;
}
