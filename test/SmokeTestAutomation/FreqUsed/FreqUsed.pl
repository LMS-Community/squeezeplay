#!/usr/perl -w
use strict;
use warnings;


sub GetMonthInNum($)
{
	my($sMonthInLetter) = @_;
	my %dMonthsInNum =
	(	
		'Jan' => '01',
		'Feb' => '02',
		'Mar' => '03',
		'Apr' => '04',
		'May' => '05',
		'Jun' => '06',
		'Jul' => '07',
		'Aug' => '08',
		'Sep' => '09',
		'Oct' => '10',
		'Nov' => '11',
		'Dec' => '12'	
	);
	
	return $dMonthsInNum{$sMonthInLetter};
}


sub GetZeroDay($)
{
	my($sDayInSingleDigit) = @_;
	my %dZeroDays =
	(
		'1' => '01',
		'2' => '02',
		'3' => '03',
		'4' => '04',
		'5' => '05',
		'6' => '06',
		'7' => '07',
		'8' => '08',
		'9' => '09',	
	);

	return $dZeroDays{$sDayInSingleDigit};
}


sub GetCurrentDateInDash()
{
	my $sNow = localtime time;
        my @aNow = split(/ /, $sNow);
        my $sMonthInLetter = $aNow[1];
        my $sDayRaw;
        my $sYear;
        my $sMonthInNum = GetMonthInNum($sMonthInLetter);
        my $sDay;
        my $sCurrentDateInDash;

	if(4 == $#aNow)
	{
		$sDayRaw = $aNow[2];
		$sYear = $aNow[4];
	}
	elsif(5 == $#aNow)
	{
		$sDayRaw = $aNow[3];
		$sYear = $aNow[5];
	}
	else
	{
		print "There are $#aNow plus one elements in the aNow array.  It is not 4 or 5.\n";
	}

        if($sDayRaw =~ /^[0-9]$/)
        {
                #$sDay = GetZeroDay($sDayRaw);
                $sDay = '0' . $sDayRaw;
        }
        else
        {
                $sDay = $sDayRaw;
        }

        chomp($sYear);

	$sCurrentDateInDash = $sYear . "-" . $sMonthInNum . "-" . $sDay;

	return $sCurrentDateInDash;
}


sub GetCurrentHourMin()
{
	my $sNow = localtime time;
	my @aNow = split(/ /, $sNow);
	my $sTime;
	my @aTime;
	my $sHour;
	my $sMin;
	my $sHourMin;

	print "\$sNow is $sNow.\n";

	if(4 == $#aNow)
	{
		$sTime = $aNow[3];
	}
	elsif(5 == $#aNow)
	{
		$sTime = $aNow[4];
	}
	else
	{
		print "Something is fishy.  \$\#aNow is $#aNow, not 4 nor 5.\n";
	}
	
	print "\$sTime is $sTime.\n";

	@aTime = split(/:/, $sTime);
	$sHour = $aTime[0];
	$sMin = $aTime[1];

	$sHourMin = $sHour . ":" . $sMin;

	print "\$sHourMin is $sHourMin.\n";

	return $sHourMin;
}


=pod
sub GetNameOfNightly($)
{
	my($sRelease) = @_;
	my $sNow = localtime time;
	my @aNow = split(/ /, $sNow);
	my $sMonthInLetter = $aNow[1];
	my $sDayRaw;
	my $sYear;
	my $sMonthInNum = GetMonthInNum($sMonthInLetter);
	my $sDay;
	my $sNightly;

	if(4 == $#aNow)
	{
		$sDayRaw = $aNow[2];
		$sYear = $aNow[4];
	}
	elsif(5 == $#aNow)
	{
		$sDayRaw = $aNow[3];
		$sYear = $aNow[5];
	}
	else
	{
		print "There are $#aNow plus one elements in the aNow array.  It is not 4 or 5.\n";
	}

	if($sDayRaw =~ /^[0-9]$/)
	{
		#$sDay = GetZeroDay($sDayRaw);
		$sDay = '0' . $sDayRaw;	
	}
	else
	{
		$sDay = $sDayRaw;
	}

	chomp($sYear);

	print "\$sNow is $sNow.\n";
	print "\$sYear is $sYear.\n";
	print "\$sMonthInLetter is $sMonthInLetter.\n";
	print "\$sMonthInNum = $sMonthInNum.\n";
	print "\$sDay is $sDay.\n";

	chomp($sRelease);

	if(7 == $sRelease)
	{
		$sNightly = "SqueezeCenter_7\.0_v" . $sYear . "-" . $sMonthInNum . "-" . $sDay . "\.dmg";
		print "\$sNightly is $sNightly.\n";
		 
	}
	elsif(6 == $sRelease)
	{
		$sNightly = "SlimServer_6\.5_v" . $sYear . "-" . $sMonthInNum . "-" .$sDay . "\.dmg";
		print "\$sNightly is $sNightly.\n";
	}
	elsif(701 == $sRelease)
	{
		$sNightly = "SqueezeCenter_7\.0\.1_v" . $sYear . "-" . $sMonthInNum . "-" .$sDay . "\.dmg";
		print "\$sNightly is $sNightly.\n";
	}
	else
	{	
		print "$sRelease is not a valid release number.  It needs to be either 6, 7,  or 701.\n";
	}
	
	return $sNightly;
}
=cut


#main()
{
	1;
	#GetNameOfNightly("7");
	#GetCurrentHourMin();
}
