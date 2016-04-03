use XML::LibXML;
use DateTime;

$weight = 75;
$age = 29;
$resolution = 1;
$timezone = -1;

opendir $dir, "." or die("Nope!");

@files = readdir $dir;

closedir $dir;

$filecount = @files;

for($i=0; $i<$filecount;$i++)
{
	@splitfile = split(/\./, $files[$i]);

	if (lc($splitfile[1]) eq "hrm")
	{
		push(@hrmfiles, $splitfile[0]);
	}
	
	if (lc($splitfile[1]) eq "gpx")
	{
		push(@gpxfiles, $splitfile[0]);
	}
	
	if (lc($splitfile[1]) eq "tcx")
	{
		push(@tcxfiles, $splitfile[0]);
	}
	
}

$hrmcount = @hrmfiles;
$gpxcount = @gpxfiles;
$tcxcount = @tcxfiles;


for ($j=0; $j<$hrmcount; $j++)
{	

	$hrm2use = $hrmfiles[$j] . ".hrm";
	$gpx2use = "";
	$hastcx = 0;
	@hrvalues = ();
	@altvalues = ();
	@speedvalues = ();
	@lat = ();
	@lon = ();
	@gpxtime = ();
	@distance = ();
	
	$date = "";
	$starttime = "";
	
	
	for ($k=0; $k<$tcxcount; $k++)
	{
		if ($hrmfiles[$j] eq $tcxfiles[$k])
		{
			$hastcx = 1;
		}
	}
	
	
	
	if ($hastcx == 0)
	{
		for ($l=0; $l<$gpxcount; $l++)
		{
			if ($hrmfiles[$j] eq $gpxfiles[$l])
			{
				$gpx2use = $hrmfiles[$j] . ".gpx";
			}
		}
		
		#parsing hrm
		
		open($outfile, ">", $hrmfiles[$j] . ".tcx");
		open($inhrm, "<", $hrm2use);
		
		$hrdatareached = 0;
		
		while ($hrmrow = <$inhrm>)
		{
			if (substr($hrmrow, 0, 5) eq "Date=")
			{
				$date = substr($hrmrow, 5, 8);
			}
			
			if (substr($hrmrow, 0, 10) eq "StartTime=")
			{
				$starttime = substr($hrmrow, 10, 8);
			}
			

		
			if ($hrdatareached == 1)
			{

				@temp = split( /\t/, $hrmrow);
				
				$temp[0]=~s/\n//g;
				$temp[1]=~s/\n//g;
				$temp[2]=~s/\n//g;
				
				
				push(@hrvalues, $temp[0]);
				push(@speedvalues, $temp[1]/10);
				push(@altvalues, $temp[2]);
						
			}
			
			
			
			if (substr($hrmrow, 0, 8) eq "[HRData]")
			{
				$hrdatareached = 1;
			}
		}

		close $inhrm;
		
		#timestamp
		
		$ts = DateTime->new(
			year 	=> substr($date,0,4),
			month	=> substr($date,4,2),
			day		=> substr($date,6,2),
			hour	=> substr($starttime, 0,2),
			minute	=> substr($starttime, 3,2),
			second	=> substr($starttime, 6,2),
			);
		
		$ts = $ts->add(hours => $timezone);
		
		$startts = $ts->ymd .'T'. $ts->hms . 'Z';
		
		#parsing gpx
		
		$maxspeed = 0;
		$distance = 0;
		
		if ($gpx2use != "")
		{
			open($tempfile, ">" , 'tempgpx.gpx');
			open($oldgpx, "<", $gpx2use);
			
			while ($gpxrow = <$oldgpx>)
			{
				
				if (substr($gpxrow, 0, 4) eq '<gpx')
				{
				print $tempfile "<gpx>\n";
				} else {
				print $tempfile $gpxrow;
				}
			}
			
			close $oldgpx;
			close $tempfile;
			
			$parser = XML::LibXML->new();
			$file = $parser->parse_file('tempgpx.gpx');
			
			@trkpoints = $file->findnodes('gpx/trk/trkseg/trkpt');
			
			$trkcount = @trkpoints;
			
		
			for ($m=0; $m<$trkcount; $m++)
			{
				push(@lat, $trkpoints[$m]->getAttribute('lat'));
				push(@lon, $trkpoints[$m]->getAttribute('lon'));
				push(@gpxtime, $trkpoints[$m]->findvalue('time'));
			}
			
			unlink 'tempgpx.gpx'; 
		
			#distance counter & max speed
		
			$speedcount = @speedvalues;
										
			for ($o=0; $o<$speedcount-1; $o++)
			{

				if ($o > 0)
				{

					push(@distance, ($speedvalues[$o]/3.6*$resolution +  $distance[$o-1]));
					
				} else {
				
					push(@distance, ($speedvalues[$o]/3.6*$resolution));

				}
				
				if ($speedvalues[$o]>$maxspeed)
				{
					$maxspeed = $speedvalues[$o];
				}
			$distance = @distance[$o];
			
			}
		
			#corecting 0 altitude
			
			$altitudecount = @altvalues;
			$fakealtitude = 0;
			
			for ($k=0; $k<$altitudecount-1;$k++)
			{
				if ($fakealtitude == 0)
				{
					$fakealtitude = $altvalues[$k]
				}
			}
		
		}	
	
		#calorie counter, avg hr and max hr
		
		$hrcount = @hrvalues;
		
		$calorie = 0;
		print "$hrm2use";
		
		$hravg = 0;
		$hrsum = 0;
		$maxhr = 0;

		for ($n=0; $n<$hrcount-1; $n++)
		{
			$calorie = $calorie + ((($age*0.2017)+(75*0.09036*2.2)+($hrvalues[$n]*0.6309)-55.0969)*($resolution/60)/4.184);
			
			$hrsum = $hrsum + $hrvalues[$n];
			$hravg = $hrsum/($n+1);
			
			if ($hrvalues[$n]>$maxhr)
			{
				$maxhr = $hrvalues[$n];
			}
			
		}
		
		if ($gpx2use != "")
		{
		print " - GPX found";
		}
	
		

		print $outfile '<?xml version="1.0"?>' . "\n";;
		print $outfile '<TrainingCenterDatabase xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">' . "\n";
		print $outfile "\t<Activities>\n";
		print $outfile "\t\t" . '<Activity Sport="Other">' . "\n";
		print $outfile "\t\t\t" . '<Id>' . $startts . '</Id>' . "\n";
		print $outfile "\t\t\t" . '<Lap SartTime="' . $startts . '">' . "\n";
		print $outfile "\t\t\t\t" . "<TotalTimeSeconds>" . ($hrcount-1 * $resolution) . "</TotalTimeSeconds>\n";
		print $outfile "\t\t\t\t" . "<DistanceMeters>$distance</DistanceMeters>\n";
		print $outfile "\t\t\t\t" . "<MaximumSpeed>$maxspeed</MaximumSpeed>\n";
		print $outfile "\t\t\t\t" . "<Calories>$calorie</Calories>\n";
		print $outfile "\t\t\t\t" . "<AverageHeartRateBpm>\n";
		print $outfile "\t\t\t\t\t" . "<Value>$hravg</Value>\n";
		print $outfile "\t\t\t\t" . "</AverageHeartRateBpm>\n";
		print $outfile "\t\t\t\t" . "<MaximumHeartRateBpm>\n";
		print $outfile "\t\t\t\t\t" . "<Value>$maxhr</Value>\n";
		print $outfile "\t\t\t\t" . "</MaximumHeartRateBpm>\n";
		print $outfile "\t\t\t\t" . "<Intensity>Active</Intensity>\n";
		print $outfile "\t\t\t\t" . "<TriggerMethod>Manual</TriggerMethod>\n";
		print $outfile "\t\t\t\t" . "<Track>\n";
		
		for ($xy = 0; $xy<$hrcount-1;$xy++)
		{
			
			$trkpointtime = $ts->ymd .'T'. $ts->hms . 'Z';
		
			print $outfile "\t\t\t\t\t" . "<Trackpoint>\n"; 
			print $outfile "\t\t\t\t\t\t" . "<Time>$trkpointtime</Time>\n"; 
			if ($gpx2use != "")
			{
				print $outfile "\t\t\t\t\t\t" . "<Position>\n";
				print $outfile "\t\t\t\t\t\t\t" . "<LatitudeDegrees>$lat[$xy]</LatitudeDegrees>\n";
				print $outfile "\t\t\t\t\t\t\t" . "<LongitudeDegrees>$lon[$xy]</LongitudeDegrees>\n";
				print $outfile "\t\t\t\t\t\t" . "</Position>\n";
				
				if ($altvalues[$xy] == 0)
				{
				
					print $outfile "\t\t\t\t\t\t" . "<AltitudeMeters>$fakealtitude</AltitudeMeters>\n";
					
				} else {
				
					print $outfile "\t\t\t\t\t\t" . "<AltitudeMeters>$altvalues[$xy]</AltitudeMeters>\n";
					
				}
				
				print $outfile "\t\t\t\t\t\t" . "<DistanceMeters>$distance[$xy]</DistanceMeters>\n";
			} 
		
			print $outfile "\t\t\t\t\t\t" . "<HeartRateBpm>\n"; 
			print $outfile "\t\t\t\t\t\t\t" . "<Value>$hrvalues[$xy]</Value>\n"; 
			print $outfile "\t\t\t\t\t\t" . "</HeartRateBpm>\n";
			print $outfile "\t\t\t\t\t" . "</Trackpoint>\n"; 
			
			$ts->add( seconds => 1);
		
		}
		
		print $outfile "\t\t\t\t" . "</Track>\n";
		print $outfile "\t\t\t" . "</Lap>\n";
		print $outfile "\t\t\t" . "<Notes></Notes>\n";
		print $outfile "\t\t" . "</Activity>\n";
		print $outfile "\t" . "</Activities>\n";       
		print $outfile "\t" . '<Author xsi:type="Application_t">' ."\n";
		print $outfile "\t\t" . '<Name>Perl Polar2TCX</Name>' ."\n";
		print $outfile "\t" . "</Author>\n";   
		print $outfile "</TrainingCenterDatabase>\n";   
	

	}

print "\n";
	
close $outfile;
	
}	
