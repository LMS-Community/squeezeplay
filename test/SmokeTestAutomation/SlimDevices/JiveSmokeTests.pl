#!/usr/perl -w
=pod
=head1	Name:	JiveSmokeTests71.pl
=head1	Who:	Wallace Lai
=head1	When:	20080520
=head1	What:
=head3	This script first searches for new firmware build of Jive.  If a new build exists, downloads it.
=head3 	This script then starts the smoke tests on a physical Jive unit with the new firmware.
=head3	After the tests are finished, tests result is copied here and parsed.
=head3	At the end of the run, both the raw and parsed results are copied over to a web server.
=cut


use strict;
use warnings;

use LWP::Simple;
use Proc::Background;
#use Cwd qw(chdir);

require "../FreqUsed/FreqUsed.pl";

our $gsInputRelease = $ARGV[0];
our $gsLatestURL = "/home/testpc03adm/TestThisBuild/NewBuild/";
#our $gsLatestURL = "http://www.slimdevices.com/downloads/nightly/latest/";
#our $gsLatestURL = "http://www.DAutoTestsWeb.com/downloads/nightly/latest/";
our $gsNightly;
our $gsJiveIP; 
our $gsPFBeingUsedInput = "/home/testpc03adm/TestsScripts_ParaBuild/InputFiles/BeingUsed";
our $gsPFBeingUsedCache = "/var/lib/squeezecenter/cache/BeingUsed";

=pod
if("7.1" eq $gsInputRelease)
{
	 $gsJiveIP = "172.19.114.59";
}
elsif("7.2" eq $gsInputRelease)
{
	 $gsJiveIP = "172.19.114.113"; 
}
elsif("7.3" eq $gsInputRelease)
{
	 $gsJiveIP = "172.19.114.xxx"; 
}
else
{
	print "Unknown input release.\n";
}
=cut

=pod
=cut
sub Usage()
{
	print "perling $0\n";
	if($#ARGV < 0)
	{
		print "This script, $0, requires one param -- the release number.\n";
		print "For example: perl $0 7.1.\n";
		die $!;
	}
}


=pod
=cut
sub TimeYet($)
{
	my ($sDesiredHourMin) = @_;
	my $sCurrentHourMin = GetCurrentHourMin();
	my $bTimeYet = 0;

	if($sDesiredHourMin eq $sCurrentHourMin)
	{
		$bTimeYet = 1;
	}
	else
	{
		$bTimeYet = 0;
	}

	return $bTimeYet;
}


=pod
=cut
sub HourYet($)
{
	my ($sDesiredHour) = @_;
	my $sCurrentHourMin = GetCurrentHourMin();
	my @aCurrentHourMin = split(/:/, $sCurrentHourMin);
	my $sCurrentHour = $aCurrentHourMin[0];
	my $bHourYet;

	$sCurrentHour =~ s/^0//;
	
	print "\$sCurrentHour is $sCurrentHour.\n";

	if($sCurrentHour >= $sDesiredHour)
	{
		$bHourYet = 1;
	}
	else
	{
		$bHourYet = 0;
	}

	return $bHourYet;
}


=pod
This version is for getting the build version from the DL web site.  Do not use if tht is not where it is getting the build.
=cut
=pod
sub GetBuildVer($$$$$)
{
        my ($sRelease, $sDLDir, $sOS, $sOver, $sCPU) = @_;
        #my $sURL = "http://www.slimdevices.com/downloads/nightly/latest/" . $sDLDir;
        #my $sURL = "http://www.DAutoTestsWeb.com/downloads/nightly/latest/" . $sDLDir;
	my $sURL =  $gsLatestURL . $sDLDir; 

	my $sContent = get($sURL);
        my @aContent;
        #my $nLastBuildTested;
        my $nBuildVer;
        my $sEachLine;
        my $sLineWithBuild;
        my @aLineWithBuild;
        my $sLineWithBuildVer;
        my @sLineWithBuildVer;
        my @aLineWithBuildVer;
        my $sBuildVer;

        print "Inside GetBuildVer\(\).\n";
        print "\$sRelease is $sRelease.\n";

        #$nLastBuildTested = GetLastBuildTested($sRelease, $sDLDir, $sOS, $sOver, $sCPU);

        if($sContent =~ m/jive\_$sRelease\_r\d+.bin/)
        {
                @aContent = split(/\n/, $sContent);

                foreach $sEachLine(@aContent)
                {
                        if($sEachLine =~ m/jive\_$sRelease\_r\d+.bin/)
                        {
                                $sLineWithBuild = $sEachLine;
                                print "\$sLineWithBuild is $sLineWithBuild.\n";
                                @aLineWithBuild = split(/>jive\_$sRelease\_r/, $sLineWithBuild);
                                $sLineWithBuildVer = $aLineWithBuild[1];
                                print "\$sLineWithBuildVer is $sLineWithBuildVer.\n";
                                @aLineWithBuildVer = split(/.bin/, $sLineWithBuildVer);
                                $nBuildVer = $aLineWithBuildVer[0];
                                print "\$nBuildVer is $nBuildVer.\n";

#=pod
                                if($nBuildVer > $nLastBuildTested)
                                {
                                        print "$nBuildVer is bigger than $nLastBuildTested.\n";
                                }
                                else
                                {
                                        print "$nBuildVer is not greater than $nLastBuildTested.\n";
                                        print "Setting \$nBuildVer to NoNewBuildYet.\n";
                                        $nBuildVer = "NoNewBuildYet";
                                }
#=cut
                        }
                }
        }
        else
        {
                $nBuildVer = "NoNewBuildYet";
                print "\$nBuildVer is $nBuildVer.\n";
        }

        return $nBuildVer;
}
=cut


=pod
This version is for if the build is scp'ed to this system by builder.
=cut
sub GetBuildVer($$$$$)
{
        my ($sRelease, $sDLDir, $sOS, $sOver, $sCPU) = @_;
        #my $sURL = "http://www.slimdevices.com/downloads/nightly/latest/" . $sDLDir;
        #my $sURL = "http://www.DAutoTestsWeb.com/downloads/nightly/latest/" . $sDLDir;
	my $sURL =  $gsLatestURL . $sDLDir; 

	my $sContent = get($sURL);
        my @aContent;
        #my $nLastBuildTested;
        my $nBuildVer;
        my $sEachLine;
        my $sLineWithBuild;
        my @aLineWithBuild;
        my $sLineWithBuildVer;
        my @sLineWithBuildVer;
        my @aLineWithBuildVer;
        my $sBuildVer;
	my $sPFJiveBin = $gsLatestURL . "jive_" . $sRelease . "_r*.bin";
	my $sJiveBinRaw = `ls -1 $sPFJiveBin`;
	my @aJiveBinRaw = split(/\n/, $sJiveBinRaw);
	my $sJiveBin = $aJiveBinRaw[0];
	my $sFile;

        print "Inside GetBuildVer\(\).\n";
        print "\$sRelease is $sRelease.\n";

        #$nLastBuildTested = GetLastBuildTested($sRelease, $sDLDir, $sOS, $sOver, $sCPU);
        
	print "\$sJiveBin is $sJiveBin.\n";

	$sJiveBin =~ s/$gsLatestURL//;
	print "\$sJiveBin after sub is $sJiveBin.\n";

	chomp($sJiveBin);
	print "\$sJiveBin after chomp is $sJiveBin.\n";

	if(!$sJiveBin)
	{
		$nBuildVer = "NoNewBuildYet";
		print "\$nBuildVer is $nBuildVer.\n";
	}
	elsif($sJiveBin =~ m/jive\_$sRelease\_r\d+.bin/)
        {
		$nBuildVer = $sJiveBin;
		$nBuildVer =~ s/jive_//;
		$nBuildVer =~ s/$sRelease//;
		$nBuildVer =~ s/_r//;
		$nBuildVer =~ s/\.bin//;
		print "\$nBuildVer is $nBuildVer.\n";

        }
        else
        {
                $nBuildVer = "NoNewBuildYet";
                print "\$nBuildVer is $nBuildVer.\n";
        }

        return $nBuildVer;
}


=pod
=cut
sub CheckMD5($$)
{
	my ($sRelease, $nBuildVer) = @_;
	my $sMD5Sum;
	my $sJiveBin = "jive_" . $sRelease . "_r" . $nBuildVer . ".bin";
	my $sPFJiveBin = $gsLatestURL . $sJiveBin;
	my $sPFMD5 = $sPFJiveBin . ".md5";
	#my $sPFSha = $sPFJiveBin . ".sha";
	my @aMD5SumOnFile;
	my $sMD5SumOnFile;
	#my @aShaSumOnFile;
	#my $sShaSumOnFile;
	my $sReturnValue = "COULDNOTCHECK";

	open(hMD5, "$sPFMD5");
	@aMD5SumOnFile = (<hMD5>);
	$sMD5SumOnFile = $aMD5SumOnFile[0];
	chomp($sMD5SumOnFile);
	print "\$sMD5SumOnFile is $sMD5SumOnFile.\n";

	$sMD5Sum = `md5sum $sPFJiveBin`;
	chomp($sMD5Sum);
	$sMD5Sum =~ s/$gsLatestURL//;
	print "\$sMD5Sum is $sMD5Sum.\n";

	if($sMD5Sum eq $sMD5SumOnFile)
	{
		$sReturnValue = "PASS";
	}
	else
	{
		$sReturnValue = "FAIL";
	}
	
	return $sReturnValue;
}


=pod
=cut
sub GetLastBuildTested($$$$$)
{
        my ($sRelease, $sDLDir, $sOS, $sOver, $sCPU) = @_;
        my $nLastBuildTested;
        my $sPFLastBuildTested;

        print "Inside GetLastBuildTested\(\).\n";
	print "\$sRelease is $sRelease.\n";
        print "\$sDLDir is $sDLDir.\n";
	print "\$sOS is $sOS.\n";
        print "\$sOver is $sOver.\n";
	print "\$sCPU is $sCPU.\n";
        
	$sRelease =~ s/\-//;
        $sRelease =~ s/\_//;
        $sRelease =~ s/\.//g;

        print "\$sRelease is $sRelease.\n";

        if("Yes" eq $sOver)
        {
                $sOver = "Over";
        }
        elsif("Nothing" eq $sOver)
        {
                $sOver = "";
        }
        else
        {
                print "\$sOver is $sOver.  It needs to be either Yes or Nothing.  Actually, it does not matter now.\n";
        }

        $sPFLastBuildTested = "../InputFiles/" . "LastTested" . $sRelease . $sDLDir . $sOS . $sCPU . ".txt";

        open(hLASTBUILDTESTED, "<$sPFLastBuildTested") or die "Cannot open $sPFLastBuildTested.  $!.\n";

        while(<hLASTBUILDTESTED>)
        {
                $nLastBuildTested = $_;
                print "\$nLastBuildTested is $nLastBuildTested.\n";
        }

        chomp($nLastBuildTested);
        print "\$nLastBuildTested is $nLastBuildTested.\n";

	close(hLASTBUILDTESTED);

        return $nLastBuildTested;
}


=pod
=cut
sub MarkVerTested($$$$$$)
{
        my ($sRelease, $sDLDir, $sOS,  $sOver, $sCPU, $sBuildVer) = @_;
        my $sPFLastBuildTested;

	print "Inside MarkVerTested.\n";

	chomp($sBuildVer);

	$sRelease =~ s/\-//;
        $sRelease =~ s/\_//;
        $sRelease =~ s/\.//g;

        if("Yes" eq $sOver)
        {
                $sOver = "Over";
        }
        elsif("Nothing" eq $sOver)
        {
                $sOver = "";
        }
        else
        {
                print "\$sOver is $sOver.  It needs to be either Yes or Nothing.\n";
        }

        $sPFLastBuildTested = "../InputFiles/" . "LastTested" . $sRelease . $sDLDir . $sOS . $sOver . $sCPU . ".txt";
	print "\$sPFLastBuildTested is $sPFLastBuildTested.\n";
	print "\$sBuildVer is $sBuildVer.\n";
        open(hLASTBUILDTESTED, "> $sPFLastBuildTested") or die "Cannot open $sPFLastBuildTested.  $!.\n";
        print hLASTBUILDTESTED "$sBuildVer";
        close(hLASTBUILDTESTED);
	print "End of MarkVerTested.\n";
}


=pod
=cut
sub GetJiveBin($$$$)
{
	my ($sRelease, $sDLDir, $sBuildVer, $sTestsLogsDir) = @_;
	my $sDirURL;
	my $sNightlyURL;
	my $sNightlyMD5;
	my $sNightlySha;
	my $sNightly = "jive_" . $sRelease . "_r" . $sBuildVer . ".bin";
	my $sTargetFile = "/home/testpc03adm/TestThisBuild/" . $sNightly;
	my $sTargetMD5 = $sTargetFile . ".md5";
	my $sTargetSha = $sTargetFile . ".sha";
	my $sJiveVerURL;
	my $sTargetJiveVer = "/home/testpc03adm/TestThisBuild/jive.version";
	#my $sTestsLog = $sTestsLogsDir . "/DownLoadJiveBin.txt";
	my $sTestsLog = $sTestsLogsDir . "/DownLoadJiveBin.ForMyEyesOnly";
	my $nReturnValue;
	open(hTestsLog, ">$sTestsLog");
	
	chomp($sRelease);	

	#$sDirURL = "http://www.slimdevices.com/downloads/nightly/latest/" . $sDLDir . "/";
	$sDirURL = $gsLatestURL . $sDLDir . "/";
	$sNightlyURL = $gsLatestURL . $sNightly;
	print "\$sNightlyURL is $sNightlyURL.\n";

	$sNightlyMD5 = $sNightlyURL . ".md5";
	print "\$sNightlyMD5 is $sNightlyMD5.\n";
	
	$sNightlySha = $sNightlyURL . ".sha";
	print "\$sNightlySha is $sNightlySha.\n";

	`cp $sNightlyURL $sTargetFile`;
	sleep 10;

	`cp $sNightlyMD5 $sTargetMD5`;
	sleep 10;

	`cp $sNightlySha $sTargetSha`;
	sleep 10;

	print hTestsLog "--TESTCASE--  Getting $sNightlyURL to $sTargetFile.\n";

	if(-e $sTargetFile)
	{
		print "$sTargetFile had already been downloaded.  No need to getstore it again.\n";
	}
	else
	{
		getstore $sNightlyURL, $sTargetFile;
		sleep 300;
	}

	if(-e $sTargetFile)
	{
		print hTestsLog "--PASS--  $sTargetFile is here.\n";
		$nReturnValue = 0;
	}
	else
	{
		print hTestsLog "--FAIL-- $sTargetFile is not here.\n";
		$nReturnValue = 1;
		return $nReturnValue;
	}


	$sJiveVerURL = $sDirURL . "jive.version";

	print hTestsLog "--TESTCASE--  Getting $sJiveVerURL to $sTargetJiveVer.\n";

	getstore $sJiveVerURL, $sTargetJiveVer;

	sleep 60;

	if(-e $sTargetJiveVer)
	{
		print hTestsLog "--PASS--  $sTargetJiveVer is here.\n";
		$nReturnValue = 0;
	}
	else
	{
		print hTestsLog "--FAIL-- $sTargetJiveVer is not here.\n";
		$nReturnValue = 1;
	}

	close(hTestsLog);
	return $nReturnValue;
}


=pod
=cut
sub CheckIfNightlyTested($)
{
	my ($sRelease) = @_;
	my $sNightly = GetNameOfNightly($sRelease);
	my $sPFNightliesTested = "../InputFiles/NightliesTested.txt";
	my @aAllLines;
	my $sEachLine;
	my $bTested = 0;
	#my $sPFNightly = "/home/testpc03adm/TestThisBuild/NewBuild/" . $sNigtly;
	#my $sPFNightlyMD5 = $sPFNightly . ".md5";
	#my $sPFNightlySha = $sPFNightly . ".sha";
								
	open(hNightliesTested, "$sPFNightliesTested");

	@aAllLines = (<hNightliesTested>);

	foreach $sEachLine (@aAllLines)
	{
		if($sEachLine =~ m/$sNightly/)
		{
			print "$sNightly is already tested.\n";
			#unlink($sPFNightly);
			#unlink($sPFNightlyMD5);
			#unlink($sPFNightlySha);
			$bTested = 1;
			close(hNightliesTested);
			return $bTested;	
		}
		else
		{
			$bTested = 0;
		}
	}
	
	close(hNightliesTested);
	return $bTested;
}


=pod
=cut
sub GetNameOfOS()
{
=pod
	my $sKernel = `uname -r`;
	my $sMacOS;


	if($sKernel =~ m/^7/)
	{
		$sMacOS = "Panther";
	}
	elsif($sKernel =~ m/^8/)
	{
		$sMacOS = "Tiger";
	}
	elsif($sKernel =~ m/^9/)
	{
		$sMacOS = "Leopard";
	}
	else
	{
		$sMacOS = "UnknownOS";
	}

	return $sMacOS;
=cut
	my $sOS = "jive";
	return $sOS;
}


=pod
=cut
sub GetNameOfNightly($$)
{
	my($sRelease, $sBuildVer) = @_;
	my $sNightly = "jive_" . $sRelease . "_r" . $sBuildVer . ".bin";
	return $sNightly;
}


=pod
=cut
sub GetNameOfTestsLogsDir($$$$$$$)
{
	my ($sRelease, $sDLDir, $sOS, $sOver, $sDownGrade, $sCPU, $sBuildVer) = @_;
	my $sNightly = GetNameOfNightly($sRelease, $sBuildVer);
	my $sNightlyNoBin = $sNightly;
	my $sTestsLogsDir;
	#my $sKernel = `uname -r`;
	#my $sMacOS = GetNameOfOS();
	#my $sOS = GetNameOfOS();
	$sNightlyNoBin =~ s/\.bin//;

	if("Nothing" eq $sOver && "Nothing" eq $sDownGrade)
	{
		#$sTestsLogsDir = "../SmokeRes/" . $sNightly . "_DownLoadedFrom_" . $sDLDir . "_TestsLogs" . "On" . $sOS . "On" . $sCPU;
		$sTestsLogsDir = "../SmokeRes/" . $sNightly . "_TestsLogs" . "On" . $sOS . "On" . $sCPU;
	}
	elsif("Nothing" ne $sOver)
	{
		#$sTestsLogsDir = "../SmokeRes/" . $sNightly . "_DownLoadedFrom_" . $sDLDir . "_Over_" . $sOver . "_TestsLogs" . "On" . $sOS . "On" . $sCPU;
		$sTestsLogsDir = "../SmokeRes/" . $sNightly . "_Over_" . $sOver . "_TestsLogs" . "On" . $sOS . "On" . $sCPU;
	}
	elsif("Nothing" ne $sDownGrade)
	{
		#$sTestsLogsDir = "../SmokeRes/" . $sNightly . "_DownLoadedFrom_" . $sDLDir . "_DownGradeTo_" . $sDownGrade . "_TestsLogs" . "On" . $sOS . "On" . $sCPU;
		$sTestsLogsDir = "../SmokeRes/" . $sNightly . "_DownGradeTo_" . $sDownGrade . "_TestsLogs" . "On" . $sOS . "On" . $sCPU;
	}
	else
	{
		print "\$sOver is $sOver.  \$sDownGrade is $sDownGrade.  Either both of thme are Nothing or one of them is Nothing.  They cannot be non-Nothing at the same time.\n";
	}
	
	return $sTestsLogsDir;
}


=pod
=cut
#sub UpdateJive(string $sRelease, int $nBuildVer, string $sTestsLogsDir)
sub UpdateJive($$$)
{
	my ($sRelease, $nBuildVer, $sTestsLogsDir) = @_;	
	my $sCmd = "sudo cp /home/testpc03adm/TestThisBuild/jive_" . $sRelease . "\_r" . $nBuildVer . "\.bin /var/lib/squeezecenter/cache/custom.jive.bin";
	my $sCmdScpLogs;
	my $nTimeMax = 60;
	my $nTimeCount;
	my $bProcAlive;
	my $sProc00;
	my $sCmdSrmBmp;
	#my $sCmdJiveReboot = "ssh -l root 172.19.114.219 reboot";
	my $sCmdJiveReboot = "ssh -l root " . $gsJiveIP . " reboot";

	print"Inside UpdateJive\(\).\n";
	system("sudo cp /home/testpc03adm/TestThisBuild/jive.version /var/lib/squeezecenter/cache/custom.jive.version");
	print "Copying jive.version.\n";
	
	print "\$sCmd is $sCmd.\n";
	system($sCmd);
	sleep 2;
	print "Copying jive.bin.\n";
	sleep 2;
	#$sCmd = "scp \/home\/testpc03adm\/TestsScripts\/squeezeplay\/Macros\.lua root\@172\.19\.114\.219\:\/mnt\/mmc\/squeezeplay\/Macros\.lua";
	$sCmd = "scp \/home\/testpc03adm\/TestsScripts\/squeezeplay\/Macros\.lua root\@" . $gsJiveIP . "\:\/mnt\/mmc\/squeezeplay\/Macros\.lua";
	$sProc00 = Proc::Background->new($sCmd);
	
	for($nTimeCount = 0; $nTimeCount < $nTimeMax; $nTimeCount++)
	{
		$bProcAlive = $sProc00->alive();
		
		if(0 == $bProcAlive)
		{
			print "\$nTimeCount is $nTimeCount.\n";
			print "\$bProcAlive is $bProcAlive.  Last of the for loop.\n";
			last;
		}
		else
		{
			print "\$nTimeCount is $nTimeCount.\n";
			print "\$bProcAlive is $bProcAlive.  Sleep one more second and check again.\n";
			sleep 1;
		}
	}

	$bProcAlive = $sProc00->alive();
	if($bProcAlive)
	{
		$sProc00->die();
	}	

	print "Copied Marcros.lua to jive.\n";
	sleep 2;

=pod
	$sCmdSrmBmp = "ssh -l root 172\.19\.115\.176 rm \/mnt\/mmc\/squeezeplay\/PlaymodePlay_fail\.bmp";
	Proc::Background::timeout_system($nTimeMax, $sCmdSrmBmp);
	
	$sCmdSrmBmp = "ssh -l root 172\.19\.115\.176 rm \/mnt\/mmc\/squeezeplay\/PlaymodePause_fail\.bmp";
	Proc::Background::timeout_system($nTimeMax, $sCmdSrmBmp);

	$sCmdSrmBmp = "ssh -l root 172\.19\.115\.176 rm \/mnt\/mmc\/squeezeplay\/PlaymodeStop_fail\.bmp";
	Proc::Background::timeout_system($nTimeMax, $sCmdSrmBmp);

	print "Just removed all the screenshots of failures.\n";
=cut

	sleep 10;

	print "\$sCmdJiveReboot is $sCmdJiveReboot.\n";

	#Proc::Background::timeout_system(30, "ssh -l root 172.19.114.219 reboot");
	Proc::Background::timeout_system(30, $sCmdJiveReboot); 
	print "Just rebooted jive.\n";
	sleep 2;
	sleep 900;
	#$sCmdScpLogs = "scp root\@172\.19\.114\.219\:\/mnt\/mmc\/squeezeplay\/Macros\.lua " . $sTestsLogsDir . "\/Macros\.lua";
	$sCmdScpLogs =  "scp root\@" . $gsJiveIP  . "\:\/mnt\/mmc\/squeezeplay\/Macros\.lua " . $sTestsLogsDir . "\/Macros\.lua";
	print "\$sCmdScpLogs is $sCmdScpLogs.\n";
	Proc::Background::timeout_system($nTimeMax, $sCmdScpLogs);
	print "Copying Macros.lua back here.\n";

	sleep 10;

	#$sCmdScpLogs =  "scp root\@172\.19\.114\.219\:\/var\/log\/messages " . $sTestsLogsDir . "\/messages\.txt";
	$sCmdScpLogs =  "scp root\@" . $gsJiveIP . "\:\/var\/log\/messages " . $sTestsLogsDir . "\/messages\.txt";
	print "\$sCmdScpLogs is $sCmdScpLogs.\n";
	Proc::Background::timeout_system($nTimeMax, $sCmdScpLogs);
	print "Copying messages here.\n";

=pod
	$sCmdScpLogs =  "scp root\@172\.19\.115\.176\:\/mnt\/mmc\/squeezeplay\/PlaymodePlay_fail\.bmp " . $sTestsLogsDir . "\/PlaymodePlay_fail\.bmp";
	Proc::Background::timeout_system($nTimeMax, $sCmdScpLogs);
	print "Copying PlaymodePlay_fail.bmp here.\n";

	$sCmdScpLogs =  "scp root\@172\.19\.115\.176\:\/mnt\/mmc\/squeezeplay\/PlaymodePause_fail\.bmp " . $sTestsLogsDir . "\/PlaymodePause_fail\.bmp";
	Proc::Background::timeout_system($nTimeMax, $sCmdScpLogs);
	print "Copying PlaymodePause_fail.bmp here.\n";

	$sCmdScpLogs =  "scp root\@172\.19\.115\.176\:\/mnt\/mmc\/squeezeplay\/PlaymodeStop_fail\.bmp " . $sTestsLogsDir . "\/PlaymodeStop_fail\.bmp";
	Proc::Background::timeout_system($nTimeMax, $sCmdScpLogs);
	print "Copying PlaymodeStop_fail.bmp here.\n";
=cut
	sleep 2;
	print "End of copying log files to here.\n";
}


=pod
=cut
#sub TurnMacrosToSmoke(string $sTestsLogsDir)
sub TurnMacrosToSmoke($)
{
	my ($sTestsLogsDir) = @_;
	my $sPFMacros = $sTestsLogsDir . "\/Macros.lua";
	my $sPFSmoke = $sTestsLogsDir . "\/SmokeTests.txt";
	my @aAllLines;
	my $sLine;
	my $sTestCase;
	my $bTestRun = 0;
	my $sPFPASS = $sTestsLogsDir . "\/PASS";
	my $sPFFAIL = $sTestsLogsDir . "\/FAIL";
	my $sPFBuildPASS = "..\/SmokeRes\/PASS";
	my $sPFBuildFAIL = "..\/SmokeRes\/FAIL";
	
	if(-e $sPFMacros)
	{
		open(hMacros, "$sPFMacros");
		open(hSmoke, ">$sPFSmoke");

		@aAllLines = (<hMacros>);
	
		foreach $sLine(@aAllLines)
		{
			if($sLine =~ m/macros\=\{/)
			{
				#Do nothing.  Fun starts from next line.
				#next;
			}
			if($sLine =~ m/\=\{/)
			{
				$sTestCase = $sLine;
				$sTestCase =~ s/\=\{//;
				chomp($sTestCase);
				if($sTestCase =~ m/macros/)
				{
					#Do nothing.
				}
				elsif($sTestCase =~ m/param/)
				{
					#Do nothing.
				}
				elsif($sTestCase =~ m/autostart/)
				{
					$bTestRun = 2;
				}
				else
				{
					print hSmoke "--TESTCASE--  $sTestCase\n";
					#next;
				}	
			}
			if($sLine =~ m/passed/)
			{
				print hSmoke "--PASS--\n\n";
				$bTestRun = 1;
		
				open(hPASS, ">$sPFPASS");
				print hPASS "PASS\n";
				
				open(hBuildPASS, ">$sPFBuildPASS");
				print hBuildPASS "PASS\n";
			}
			if($sLine =~ m/failed/)
			{
				print hSmoke "--FAIL--\n\n";
				$bTestRun = 1;
				
				if(-e $sPFPASS)
				{
					unlink($sPFPASS);
				}
				
				open(hFAIL, ">$sPFFAIL");
				print hFAIL "FAIL\n";

				if(-e $sPFBuildPASS)
				{
					unlink($sPFBuildPASS);
				}
				
				open(hBuildFAIL, ">$sPFBuildFAIL");
				print hBuildFAIL "FAIL\n";
			}

			if($sLine =~ m/\}\,/)
			{
				if(1 == $bTestRun)
				{
					print "\$bTestRun is $bTestRun.  Do nothing here.\n";
				}
				elsif(0 == $bTestRun)
				{
					print hSmoke "--INFO--  This test was not run.  Test is unstable if Jive is connected to a router.  If this test is run without a router, Jive cannot connect back to SC.\n\n";
				}
				elsif(2 == $bTestRun)
				{
					print "\$bTestRun is $bTestRun.  Do nothing here.";
				}
				else
				{
					print "\bTestRun is $bTestRun.  It needs to be 0, 1, or 2.\n";
				}
				
				$bTestRun = 0;
			}
		}
	}
	else
	{
		print "$sPFMacros does not exist.  Tests failed big time.\n";
		open(hFAIL, ">$sPFFAIL");
		print hFAIL "FAIL\n";

		open(hBuildFAIL, ">$sPFBuildFAIL");
		print hBuildFAIL "FAIL\n";
	}
}


#sub EndOfRun(string $sTestsLogsDir bool $bLastTestOfRel)
sub EndOfRun($$)
{
	my ($sTestsLogsDir, $bLastTestOfRel) = @_;
	print "\$sTestsLogsDir is $sTestsLogsDir.\n";
	my $sLogsDirShared = "/mnt/win";
	#my $sDestOfLogsDir = $sLocalQAServer . "/" . $sTestsLogsDir;
	print "\$sLogsDirShared is $sLogsDirShared.\n";

	my $bUpdateWebSite = 0;

	print "Mount TestMGR.\n";
	#system("sudo mount -t smbfs -o user=testmgrAdm,password=slimdevices //testmgr/SmokeResShared $sLogsDirShared");
	TurnMacrosToSmoke($sTestsLogsDir);
	#sleep 2;
	#system("cp -r $sTestsLogsDir $sFinalDestOfLogsDir");
	#system("sudo cp -r $sTestsLogsDir $sDestOfLogsDir");
	system("sudo cp -r $sTestsLogsDir $sLogsDirShared");
	sleep 30;
	#print "Changing boot partition to Admin.\n";
	#system("sudo bless -mount '/Volumes/Admin' -setBoot -quiet");
	sleep 10;
	#print "Reboot to Admin partition right now.\n";
	print "Copied tests logs to test $sLogsDirShared.\n";
	sleep 2;
	#system("sudo shutdown -r now");
	
	if($bLastTestOfRel)
	{
		if(-e "../SmokeRes/FAIL")
		{
			print "Build failed.  Do not update web site.\n";
			$bUpdateWebSite = 0;
		}
		elsif(-e "../SmokeRes/PASS")
		{
			print "Build passed.  Update web site.\n";
			$bUpdateWebSite = 1;
		}
		else
		{
			print "There should be PASS, FAIL, or both semiphors in the SmokeRes folder.  Please check.\n ";
			$bUpdateWebSite = 0;
		}
		
		if(-e "../SmokeRes/FAIL")
		{
			unlink("../SmokeRes/FAIL");
		}
		
		if(-e "../SmokeRes/PASS")
		{
			unlink("../SmokeRes/PASS");
		}
	}
	
	return $bUpdateWebSite;
}


=pod
=cut
#sub UpdateWebSite(string $sRelease, int $nBuildVer)
sub UpdateWebSite($$)
{
	my ($sRelease, $nBuildVer) = @_;
	my $sSourceDir =  "/home/testpc03adm/TestThisBuild/";
	my $sJiveBin = "jive_" . $sRelease . "\_r" . $nBuildVer . "\.bin";
	my $sPFJiveBin = $sSourceDir . $sJiveBin;
	my $sMD5 = $sJiveBin . "\.md5";
	my $sPFMD5 = $sSourceDir . $sMD5;
	my $sSha = $sJiveBin . "\.sha";
	my $sPFSha = $sSourceDir . $sSha;
	my $sPFJiveDotVer = $sSourceDir . "jive.version";
	my $sPFVerSha = $sPFJiveDotVer . ".sha";
	my $sRelDir = $sSourceDir . $sRelease . "\/";
	my $sWebDir = "sdi\@services.web.slimdevices.com:/netapp/www/update.slimdevices.com/html/update/firmware/" . $sRelease . "/";
	#my $sThisScriptDir = "/home/testpc03adm/TestsScripts_ParaBuild/SlimDevices/";
	my $sVerSha;

	my $sCmdMkVer = "unzip \-p " . $sPFJiveBin . " jive.version \> " . $sPFJiveDotVer;
	#my $sCmdMkVerSha = "sha1 " . $sPFJiveDotVer. " \> " . $sPFVerSha;
	#my $sCmdMkVerSha = "sha1 " . $sPFJiveDotVer. " \> " . "jive.version.sha";
	my $sCmdCPBin = "sudo cp " . $sPFJiveBin . " " . $sRelDir;
	my $sCmdCPMD5 = "sudo cp " . $sPFMD5 . " " . $sRelDir;
	my $sCmdCPSha = "sudo cp " . $sPFSha . " " . $sRelDir;
	my $sCmdCPVer = "sudo cp " . $sPFJiveDotVer . " " . $sRelDir;
	my $sCmdCPVerSha = "sudo cp " . $sPFVerSha . " " . $sRelDir;
	my $sCmdUpdateWeb = "rsync -avz --delete " . $sRelDir . " " . $sWebDir;
	my $sCmdClearRelDir = "rm -f " . $sRelDir . "jive*";

	my $nTimeMax = 90;
	my $sCmd;
	my @aCmds = 
		(
			$sCmdCPBin,
			$sCmdCPMD5,
			$sCmdCPSha,
			$sCmdCPVer,
			$sCmdCPVerSha,
			$sCmdUpdateWeb,
			$sCmdClearRelDir
		);

	print "Inside UpdateWebSite\(\).\n";

	print "\$sCmdMkVer is $sCmdMkVer.\n";
	Proc::Background::timeout_system($nTimeMax, $sCmdMkVer);

	sleep 2;

	$sVerSha = `sha1 $sPFJiveDotVer`;
	print "\$sVerSha is $sVerSha.\n";
	$sVerSha =~ s/$sSourceDir//;
	print "\$sVerSha after sub is $sVerSha.\n";
	
	open(hVerSha, ">$sPFVerSha");
	print hVerSha $sVerSha;

	#chdir($sSourceDir);

	foreach $sCmd (@aCmds)
	{
		print "\$sCmd is $sCmd.\n";
		Proc::Background::timeout_system($nTimeMax, $sCmd);
		sleep 10;
	}

	#chdir($sThisScriptDir);

	print "Just finished updating the web site.\n";
}


=pod
=cut
#sub OverLord()
sub OverLord()
{
	print "sub OverLord\(\) begins.\n";

	my $sTestsLogsDir;
	my $sInputs;
	my @aInputs;
	my $sRelease;
	my @aRelease;
	my @aOS;;
	my $sOS;
	my @aDLDir;
	my $sDLDir;
	my @aOver;
	my $sOver;
	my @aCPU;
	my $sCPU;
	my $sActiveOS = GetNameOfOS();
	my $sBuildVer;
	my $nLastBuildTested;
	my @aOverRelBuild;
	my $sOverRel;
	my $nOverBuild;
	my @aDownGrade;
	my $sDownGrade;
	my @aDownToRelBuild;
	my $sDownToRel;
	my $nDownToBuild;
	my @aLastTestOfRel;
	my $bLastTestOfRel;
	my @aJiveIP;
	my $sJiveIP;
	my $sPFInputs = "../InputFiles/Inputs" . $gsInputRelease  . ".txt";
	my $sMD5Match;
	my $bUpdateWebSite = 0;

	my $sPFNightly;
	my $sPFNightlyMD5;
	my $sPFNightlySha;

	sleep 10;

	print "Check whether the cache folder is being used by AutoSmokeTest for another release.\n";

	while(-e $gsPFBeingUsedCache)
	{
		print "$gsPFBeingUsedCache exists.  Sleep 30 seconds.\n";
		sleep 30;
	}

	open(hInputs, "$sPFInputs");

	@aInputs = (<hInputs>); 

	foreach $sInputs(@aInputs)
	{
		print "\$sInputs is $sInputs.\n";

		if($sInputs =~ m/^#/)
		{
			print "This is a comment line.  Skip.\n";
		}
		else
		{

			@aRelease = split(/__RELEASE__/, $sInputs);
			$sRelease = $aRelease[1];

			@aDLDir = split(/__DLDIR__/, $sInputs);
			$sDLDir = $aDLDir[1];

			@aOS = split(/__OS__/, $sInputs);
			$sOS = $aOS[1];

			@aOver = split(/__OVER__/, $sInputs);
			$sOver = $aOver[1];

			if("Nothing" ne $sOver)
			{
				@aOverRelBuild = split(/_/, $sOver);
				$sOverRel = $aOverRelBuild[0];
				$nOverBuild = $aOverRelBuild[1];

				print "\$sOverRel is $sOverRel.\n";
				print "\$nOverBuild is $nOverBuild.\n";
			}

			@aDownGrade = split(/__DOWNGRADE__/, $sInputs);
			$sDownGrade = $aDownGrade[1];

			if("Nothing" ne $sDownGrade)
			{
				@aDownToRelBuild = split(/_/, $sDownGrade);
				$sDownToRel = $aDownToRelBuild[0];
				$nDownToBuild = $aDownToRelBuild[1];
			}

			@aCPU = split(/__CPU__/, $sInputs);
			$sCPU = $aCPU[1];

			@aLastTestOfRel = split(/__LAST__/, $sInputs);
			$bLastTestOfRel = $aLastTestOfRel[1];

			@aJiveIP = split(/__JIVEIP__/, $sInputs);
			$sJiveIP = $aJiveIP[1]; 	

			$gsJiveIP = $sJiveIP;
			print "\$gsJiveIP is $gsJiveIP.\n";
	
			if($sActiveOS eq $sOS)
			{
				$sBuildVer =  GetBuildVer($sRelease, $sDLDir, $sOS, $sOver, $sCPU);
				$nLastBuildTested = GetLastBuildTested($sRelease, $sDLDir, $sOS, $sOver, $sCPU);
				chomp($sBuildVer);
				chomp($nLastBuildTested);
				print "\$sRelease is $sRelease.\n";
				print "\$sDLDir is $sDLDir.\n";
				print "\$sOS is $sOS.\n";
				print "\$sOver is $sOver.\n";
				print "\$sCPU is $sCPU.\n";
				print "\$sBuildVer is $sBuildVer.\n";
				print "\$nLastBuildTested is $nLastBuildTested.\n";		
				
				$sMD5Match =  CheckMD5($sRelease, $sBuildVer);
				print "\$sMD5Match is $sMD5Match.\n";

				if("PASS" eq $sMD5Match)
				{	
					if("NoNewBuildYet" ne $sBuildVer)
					{
						if($sBuildVer > $nLastBuildTested)
						{
							print "\$sBuildVer is $sBuildVer.  It is bigger than \$nLastBuildTested, which is $nLastBuildTested.\n";
							
							if(-e $gsPFBeingUsedCache)
							{
								print "Something is seriously wrong.  While loops thought there is no $gsPFBeingUsedCache.\n";
							}
							else
							{
								`sudo cp $gsPFBeingUsedInput $gsPFBeingUsedCache`;
							}

							sleep 2; 
							
							$sTestsLogsDir = GetNameOfTestsLogsDir($sRelease, $sDLDir, $sOS, $sOver, $sDownGrade, $sCPU, $sBuildVer);
							system("mkdir $sTestsLogsDir");
							sleep 2;
							GetJiveBin($sRelease, $sDLDir, $sBuildVer, $sTestsLogsDir);
							sleep 2;
						
							if($bLastTestOfRel)
							{
								MarkVerTested($sRelease, $sDLDir, $sOS, $sOver, $sCPU, $sBuildVer);
								
								$sPFNightly = $gsLatestURL . "jive_" . $sRelease . "_r" . $sBuildVer . ".bin";
								$sPFNightlyMD5 = $sPFNightly . ".md5";
								$sPFNightlySha = $sPFNightly . ".sha";
							
								print "Unlinking $sPFNightly.\n";
								unlink($sPFNightly);
								sleep 2;
								print "Unlinking $sPFNightlyMD5.\n";
								unlink($sPFNightlyMD5);
								sleep 2;
								print "Unlinking $sPFNightlySha.\n";	
								unlink($sPFNightlySha);
								sleep 2;
							}

							sleep 2;
							print "Update jive.bin now.\n";

							if("Nothing" ne $sOver)
							{
								UpdateJive($sOverRel, $nOverBuild, $sTestsLogsDir);
							}
					
							sleep 60;	
		
							UpdateJive($sRelease, $sBuildVer, $sTestsLogsDir);

							sleep 60;

							if("Nothing" ne $sDownGrade)
							{
								UpdateJive($sDownToRel, $nDownToBuild, $sTestsLogsDir);
							}

							sleep 10;
							sleep 20;
							print "check if it works.\n";
							sleep 2;
							print "Do other tests here.\n";
							sleep 2;
						
							$bUpdateWebSite = EndOfRun($sTestsLogsDir, $bLastTestOfRel);

							if($bUpdateWebSite)
							{
								if($bLastTestOfRel)
								{
									UpdateWebSite($sRelease, $sBuildVer);
								}
							}

							if($bLastTestOfRel)
							{
								if(-e $gsPFBeingUsedCache)
								{
									print "Sudo removing $gsPFBeingUsedCache.\n;";
									`sudo rm $gsPFBeingUsedCache`;
									sleep 2;
								}#if(-e $gsPFBeingUsedCache)
							}#if($bLastTestOfRel)
						}
						else
						{
							print "$sBuildVer is not greater than $nLastBuildTested.  Tests had already been done on $sBuildVer from $sDLDir.\n";
							
							$sPFNightly = $gsLatestURL . "jive_" . $sRelease . "_r" . $sBuildVer . ".bin";
							$sPFNightlyMD5 = $sPFNightly . ".md5";
							$sPFNightlySha = $sPFNightly . ".sha";
							
							print "Unlinking $sPFNightly.\n";
							unlink($sPFNightly);
							sleep 2;
							print "Unlinking $sPFNightlyMD5.\n";	
							unlink($sPFNightlyMD5);
							sleep 2;
							print "Unlinking $sPFNightlySha.\n";	
							unlink($sPFNightlySha);
							sleep 2;
						}
					}
					elsif("FAIL" eq $sMD5Match)
					{
						print "\$sMD5Match is $sMD5Match.\n";
					}
					else
					{
						print "\$sMD5Match is $sMD5Match. That is not good.\n";
					}
				}
				else
				{
					print "$sBuildVer from $sDLDir.\n";
				}
			}#End of if($sActiveOS eq $sOS)
			else
			{
				print "\$sActiveOS is $sActiveOS.  It is not $sOS.\n";
			}
		}#End of if($sInputs =~ m/^#/) else
	}#End of foreach $sInputs(@aInputs)

	print "sub OverLord\(\) ends.\n";
}


=pod
=cut
#main()
{
	our $nCount;

	if($#ARGV < 0)
	{
		Usage();
	}

	if("\-?" eq  $ARGV[0] || "\-h" eq  $ARGV[0] || "\-help" eq  $ARGV[0] || "\\?" eq  $ARGV[0] || "\\h" eq  $ARGV[0])
	{
		Usage();
	}
	else
	{
		#for($nCount = 0; $nCount < 1000000000000; $nCount++)
		while(1)
		{
			until(HourYet(1))
			{
				print "It is not time yet.\n";
				sleep 60;
			}
		
			OverLord();
		
			print "Sleep a minute and check for new build again.\n";
			sleep 60;
		}
	}
}
