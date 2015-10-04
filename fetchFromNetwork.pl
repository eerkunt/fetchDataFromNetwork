#
#
# fetchFromNetwork  -    This script connects to IPs that are given as input file, then
#                        parses the output for relative commands.
#
# Author            Emre Erkunt
#                   (emre.erkunt@gmail.com)
#
# History :
# -----------------------------------------------------------------------------------------------
# Version               Editor          Date            Description
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# 0.0.1_AR              EErkunt         20141121        Initial ALPHA Release
# 0.0.2                 EErkunt         20141126        BNGMac, Vlan 103 Check, Available MAC
#                                                       Space checks added. General structure
#                                                       reworked.
# 0.0.3                 EErkunt         20141128        Add impact topology by neighbourhood
#                                                       discovery
# 0.4.0                 EErkunt         20141130        Add multi-threaded support
#                                                       Changed versioning style
# 0.4.1                 EErkunt         20141201        Max Threads changed to 5
# 0.4.2                 EErkunt         20141201        Color codes are changed based on uptime
# 0.4.3                 EErkunt         20141201        Fixed timeout for graph layout
# 0.4.4                 EErkunt         20141201        Added -g option
# 0.4.5                 EErkunt         20141202        Bugfix on CSV Output and added retry
#                                                       mechanism on fetch functions
#                                                       Telnet timeout has been increased to 240
# 0.4.6                 EErkunt         20141209        Added "c" and "g" prefix for Cisco NEs
#                                                       Added ACL Compliancy check option
#                                                       Disabled terminal pagers on remote host
# 0.4.7                 EErkunt         20141211        Fixed c/g prefix problem on cisco devices
#                                                       Fixed uptime formatting for new types
#                                                       Fixed a new line problem on CSV output
# 0.4.8                 EErkunt         20141211        Ring Leader determination algorithm added
# 0.4.9                 EErkunt         20141212        Added some extra exception handling
# 0.5.0                 EErkunt         20141212        Self-updater functionality added.
# 0.5.1                 EErkunt         20141212        Fixed an uptime formatting problem on cisco
# 0.5.2                 EErkunt         20141218        Fixed a problem on neighbor discovery on
#                                                       uptime allocation.
#                                                       Disabled extra warnings on graphic layout
#                                                       Added stddev function on graphing
# 0.5.3                 EErkunt         20141218        Fixed a problem about self-updater
# 0.5.4                 EErkunt         20141219        Added UPS check functionality
#                                                       Changed verbose functionality as reverse
# 0.5.5                 EErkunt         20141223        Fixed a problem about self-updater
# 0.5.6                 EErkunt         20141225        Added some exception handling mechanism
#                                                       for weird and random uptime problem
# 0.5.7                 EErkunt         20141226        Re-structured the whole auto-updater !!
# 0.5.8                 EErkunt         20150115        Asks for password if not used -p parameter
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
#
# Needed Libraries
#
use threads;
use threads::shared;
use Getopt::Std;
use Net::Telnet;
use Graph::Easy;
use LWP::UserAgent;
use HTTP::Headers;
use LWP::Simple;
use Statistics::Lite qw(:all);
use LWP::UserAgent;
use Term::ReadPassword::Win32;

my $version     = "0.5.8";
my $arguments   = "u:p:i:o:hvt:ga:n";
my $MAXTHREADS	= 15;
getopts( $arguments, \%opt ) or usage();
$| = 1;
print "fetchFromNetwork v".$version;
usage() if ( !$opt{u} or !$opt{p} );
usage() if (!$opt{i} or !$opt{u} or !$opt{p});
$opt{o} = "OUT_".$opt{i} unless ($opt{o});
$opt{t} = 2 unless $opt{t};
if ($opt{v}) {
	$opt{v} = 0;
} else {
	$opt{v} = 1;
}

my @targets :shared;
my @ciNames;
unlink('upgradeffn.bat');

my $time = time();

my $svnrepourl  = ""; 												# Your private SVN Repository (should be served via HTTP). Do not forget the last /
my $SVNUsername = "";													# Your SVN Username
my $SVNPassword = "";													# Your SVN Password
my $SVNScriptName = "fetchFromNetwork.pl";
my $SVNFinalEXEName = "ffn";

$ua = new LWP::UserAgent;
my $req = HTTP::Headers->new;

unless ($opt{n}) {
	#
	# New version checking for upgrade
	#
	$req = HTTP::Request->new( GET => $svnrepourl.$SVNScriptName );
	$req->authorization_basic( $SVNUsername, $SVNPassword );
	my $response = $ua->request($req);
	my $publicVersion;
	my $changelog = "";
	my $fetchChangelog = 0;
	my @responseLines = split(/\n/, $response->content);
	foreach $line (@responseLines) {
		if ( $line =~ /^# Needed Libraries/ ) { $fetchChangelog = 0; }
		if ( $line =~ /^my \$version     = "(.*)";/ ) {
			$publicVersion = $1;
		} elsif ( $line =~ /^# $version                 \w+\s+/g ) {
			$fetchChangelog = 1;
		}
		if ( $fetchChangelog eq 1 ) { $changelog .= $line."\n"; }
	}
	if ( $version ne $publicVersion and length($publicVersion)) {		# SELF UPDATE INITIATION
		print "\nSelf Updating to v".$publicVersion.".";
		$req = HTTP::Request->new( GET => $svnrepourl.$SVNFinalEXEName.'.exe' );
		$req->authorization_basic( $SVNUsername, $SVNPassword );
		if($ua->request( $req, $SVNFinalEXEName.".tmp" )->is_success) {
			print "\n# DELTA CHANGELOG :\n";
			print "# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
			print "# Version               Editor          Date            Description\n";
			print "# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n";
			print $changelog;
			open(BATCH, "> upgrade".$SVNFinalEXEName.".bat");
			print BATCH "\@ECHO OFF\n";
			print BATCH "echo Upgrading started. Ignore process termination errors.\n";
			print BATCH "sleep 1\n";
			print BATCH "taskkill /F /IM ".$SVNFinalEXEName.".exe > NULL 2>&1\n";
			print BATCH "sleep 1\n";
			print BATCH "ren ".$SVNFinalEXEName.".exe ".$SVNFinalEXEName."_to_be_deleted  > NULL 2>&1\n";
			print BATCH "copy /Y ".$SVNFinalEXEName.".tmp ".$SVNFinalEXEName.".exe > NULL 2>&1\n";
			print BATCH "del ".$SVNFinalEXEName.".tmp > NULL 2>&1\n";
			print BATCH "del ".$SVNFinalEXEName."_to_be_deleted > NULL 2>&1\n";
			print BATCH "del NULL\n";
			print BATCH "echo All done. Please run the ".$SVNFinalEXEName." command once again.\n\n";
			close(BATCH);
			print "Initiating upgrade..\n";
			sleep 1;
			exec('cmd /C upgrade'.$SVNFinalEXEName.'.bat');
			exit;
		} else {
			print "Can not retrieve file. Try again later. You can use -n to skip updating\n";
			exit;
		}
	} else {
		print " ( up-to-date )\n";
	}
} else {
	print " ( no version check )\n";
}

print "Verbose mode ON\n" if ($opt{v});
#
# Parsing CSV File
#
print "Reading input files. " if ($opt{v});
open(INPUT, $opt{i}) or die ("Can not read from file $opt{i}.");
while(<INPUT>) {
	chomp;
	if ( length($_) ) {
		if ( $_ =~ /(nw_.*);(\d*\.\d*\.\d*\.\d*)/ ) {
			push(@targets, $2);
			push(@ciNames, $1);
		}
	}
}
close(INPUT);
print "[ ".scalar @targets ." IPs parsed ] " if ($opt{v});

#
# Parsing UPS File
#
$req = HTTP::Request->new( GET => $svnrepourl.'ups.csv' );
$req->authorization_basic( $SVNUsername, $SVNPassword );
my $response = $ua->request($req);
my $publicVersion;
my $changelog = "";
my $fetchChangelog = 0;
my @responseLines = split(/\n/, $response->content);
our @upslist;

foreach $line (@responseLines) {
	my ( @columns ) = split(/;/, $line);
	push(@upslist, $columns[0]);
}
print "[ ".scalar @upslist ." UPS records parsed ]\n" if ( $opt{v} );

#
# Parsing ACL File
#
my %aclList;
if ( $opt{a} ) {
	print "Reading ACL file. " if ($opt{v});

	open(ACL, $opt{a}) or die ("Can not read from file $opt{i}.");
	my $stepIn = "";
	my $stepInVendor = "";
	my $stepInCount = 0;
	my $stepInSegmentCount = 0;

	while(<ACL>) {
		chomp;
		if ( $_ =~ /\<\/(.*)\s(.*)\>/ ) {
			# print "Step out from $1 on $stepInVendor\n";
			$stepIn = "";
			$stepInVendor = "";
		} elsif( $_ =~ /\<(.*)\s(.*)\>/ ) {
			$stepIn = $2;
			$stepInVendor = $1;
			$stepInSegmentCount++;
			# print "Step in $1 on $stepInVendor\n";

		} elsif ( $stepIn and $stepInVendor ) {
			$stepInCount++;
			# print "--> [$stepInVendor] ($stepIn) $_\n";
			$_ =~ s/^\s*//;
			$_ =~ s/\(\d* matches\)//;
			$_ =~ s/\s*$//;
			push(@{$aclList{$stepInVendor}{$stepIn}}, $_);
		}
	}
	close(ACL);

	#print Dumper(%aclList);
	print "$stepInSegmentCount acl lists and $stepInCount acl records parsed.\n" if ($opt{v});
}

my @fileOutput;
my @completed :shared;

#
# Main Loop
#
# Beware, dragons beneath here! Go away.
#
# Get the Password from STDIN
#
$opt{p} = read_password('Enter your password : ') unless ($opt{p});
print "Fetching information from ".scalar @targets." IPs.\n" if ($opt{v});
$opt{t} = $MAXTHREADS	if ($opt{t} > $MAXTHREADS);
print "Running on ".$opt{t}." threads.\n";

my @running = ();
my @Threads;


my $i = 0;
my $fh;
open($fh, "> ".$opt{o}) or die ("Can not write on $opt{o}.");
print $fh "\"CI Name\";\"IP Address\";\"Vendor\";\"Available VLAN\";\"VLAN 103 Kontrolu\";\"BNG MAC\";\"Uptime\";\"Neighborhood\"";
print $fh ";\"ACL Check\"" if ( $opt{a} );
print $fh ";\"UPS\"";
print $fh "\n";

my @DATA :shared;
my @STDOUT;
my %nodes :shared;
my %fill :shared;
my @uptimes :shared;

my %edges :shared;

my $graph = Graph::Easy->new();

while ( $i <= scalar @targets ) {
	@running = threads->list(threads::running);
	while ( scalar @running < $opt{t} ) {
		# print "New Thread on Item #$i\n";
		my $thread = threads->new( sub { &fetchDataFromNetwork( $i, $targets[$i], $ciNames[$i] );});
		push (@Threads, $thread);
		@running = threads->list(threads::running);
		$i++;
		if ( $i >= scalar @targets ) {
			last;
		}
	}

	sleep 1;
	foreach my $thr (@Threads) {
		if ($thr->is_joinable()) {
			$thr->join;
		}
	}

	last unless ($targets[$i]);
}

@running = threads->list(threads::running);
print "Waiting for ".scalar @running." pending threads.\n"  if ($opt{v});
while (scalar @running > 0) {
	foreach my $thr (@Threads) {
		if ($thr->is_joinable()) {
			$thr->join;
		}
	}
	@running = threads->list(threads::running);
}
print "\n";

# Dump the data to CSV file that has been collected from Network
foreach my $dataLine (@DATA) {
	print $fh $dataLine;
}
close($fh);


my $graphFilename = "GRAPH_".$opt{o}.".html";
if ( $opt{g} ) {
	print "Generating graph.\n"  if($opt{v});
	# Generating graph file
	print "Nodes : ["  if($opt{v});

	my $minimum = min(@uptimes);
	my $tmpMax = stddev(@uptimes);
	my @newUptimes;
	foreach my $tmpUptime (@uptimes) {
		if ($tmpUptime <= $tmpMax) {
			push(@newUptimes, $tmpUptime);
		}
	}
	my $maximum = stddev(@newUptimes);
	# print "OLD STDDEV : $tmpMax\tNEW STDDEV : $maximum\n";
	my $ringLeader = 3;

	foreach my $key (sort keys %nodes) {
		my @edgestome = grep /-$key$/, keys %edges;
		my @edgesfromme = grep /^$key-/, keys %edges;
		my $myEdgeCount = (scalar @edgestome)+(scalar @edgesfromme);
		my $node = $graph->add_node(''.$key.'');
		my $namingSuffix = "";
		my $namingPrefix = "";

		# Check for the Ringleader
		if ( $myEdgeCount >= $ringLeader ) {
			$namingSuffix = " **";
			$node->set_attribute('borderstyle', 'bold-dash');
		} else {
			$node->set_attribute('shape', 'rounded');
		}

		# Check for the UPS Existance
		my $index;
		my $myCiName;
		for(my $x=0;$x <= $#targets;$x++) {
			# print "TARGET : $targets[$x] <=> $key\n";
			if ( $key eq $targets[$x] ) {
				$myCiName = $ciNames[$x];
				#print "INDEX ($key = $targets[$x]): $x\n";
				#print "CIName ($key): $myCiName (".in_array(\@upslist, $myCiName).")\n";
				$namingPrefix = "(U) " if ( in_array(\@upslist, $myCiName) );
				last;
			}
		}

		# Add prefix and suffix on the labeling
		$node->set_attribute('label', ''.$namingPrefix.$key.$namingSuffix.'');

		# $node->set_attribute('fill', $fill{$key}) if ($fill{$key});
		$node->set_attribute('font', 'Arial');

		# Finding the correct Percentage
		if ( $nodes{$key} >= $minimum && $nodes{$key} <= $maximum ) {
			# print "Percentage for $key ($nodes{$key}) is ".gradient($minimum, $maximum, $nodes{$key})."\n";
			$node->set_attribute('fill', '#'.gradient($minimum, $maximum, $nodes{$key}));
		} else {
			if ( $nodes{$key} > $tmpMax ) {
				$node->set_attribute('fill', '#7EE8ED');
			} elsif ( $nodes{$key} > $maximum ) {
				$node->set_attribute('fill', '#5B7AD9');
			}
			# print "Skipping $key ($nodes{$key}) out of boundaries ( $minimum <=> $maximum ). Gradient might be : ".gradient($minimum, $maximum, $nodes{$key})."\n";
		}

		$node->set_attribute('fontsize', '80%');

		if ( $links{$key} ) {
			$node->set_attribute('linkbase', '/');
			$node->set_attribute('autolink', 'name');
			$node->set_attribute('link', $links{$key});
		}
		print "."  if($opt{v});
	}
	print "]\n"  if($opt{v});



	print "Connections : ["  if($opt{v});
	foreach my $key (sort keys %edges) {
		my ($source, $destination) = split(/-/, $key);
		my $edge = $graph->add_edge(''.$source.'',''.$destination.'');
		$edge->set_attribute('arrowstyle', 'none');
		print "."  if($opt{v});
	}
	print "]\n" if($opt{v});

	$graph->output_format('svg');


	$graph->timeout(600);
	$graph->catch_warnings(1);					# Disable warnings

	if ( scalar @uptimes <= 200 ) {
		print "Re-organizing the graph"  if($opt{v});
		my $max = undef;

		$graph->randomize();
		my $seed = $graph->seed();

		$graph->layout();
		$max = $graph->score();

		for (1..10) {
		  $graph->randomize();                  # select random seed
		  $graph->layout();                     # layout with that seed
		  if ($graph->score() > $max) {
			$max = $graph->score();             # store the new max store
			$seed = $graph->seed();             # and it's seed
			print "." if ($opt{v});
			}
		 }

		# redo the best layout
		if ($seed ne $graph->seed()) {
		  $graph->seed($seed);
		  $graph->layout();
		  print "." if ($opt{v});
		 }
		 print "\n"  if ($opt{v});
	}

	print "Creating graph.\n"  if($opt{v});


	open(GRAPHFILE, "> ".$graphFilename) or die("Can not create graphic file ".$graphFilename);
	print GRAPHFILE $graph->output();
	close(GRAPHFILE);
}

print "\nAll done and saved on $opt{o} ";
print "and $graphFilename." if ($opt{g});
print "\n";
print "Process took ".(time()-$time)." seconds with $opt{t} threads.\n"   if($opt{v});

#
# Related Functions
#
sub fetchDataFromNetwork() {
	my $i = shift;
	my $IP = shift;
	my $ciName = shift;

	# Graph Node
	$nodes{$targets[$i]}		 	= ''.$targets[$i].'';
	$fill{$targets[$i]}			 	= '#DBDBDB';

	if($opt{v}) {
		$STDOUT[$i] = "[".($i+1)."] -> $targets[$i] ( $ciNames[$i] ) : ";
	} else {
		$STDOUT[$i] = ".";
	}


	my $t = new Net::Telnet ( Timeout => 240 );		# Do not forget to change timeout on new development !!!!!!!!!
	$t->errmode("return");
	if ($t->open($targets[$i])) {

		my $vendorName;

		if ( $ciNames[$i] =~ /nw_sf_[c|g].*/ ) {	## This is a Cisco Switch
			$vendorName = "cisco";
		} elsif ( $ciNames[$i] =~ /nw_sf_s.*/ ) {	## This is a Huawei Switch
			$vendorName = "huawei";
		}
		$STDOUT[$i] .= "($vendorName) " if ($opt{v});
		$STDOUT[$i] .= "C " if ($opt{v});

		my $tryMe = 1;
		my $maxTry = 3;
		if ( authenticate($t, $opt{u}, $opt{p}, $vendorName) ) {
			$STDOUT[$i] .= "A " if ($opt{v});
			$DATA[$i] = $ciNames[$i].";".$targets[$i].";".$vendorName.";";
			if ( $vendorName eq "huawei" ) 	{ $STDOUT[$i] .= "[VLAN #] " if($opt{v}); $DATA[$i] .= "\"Not Applicable\";"; } # No Available VLAN Check
			elsif ($vendorName eq "cisco" ) {
				# Available VLAN on CISCO Devices
				$STDOUT[$i] .= "["  if ($opt{v});
				my $vlanCounter;

				while ( !length($vlanCounter) and $tryMe <= $maxTry) {
					$vlanCounter = parseAvailableVlan( $t );
					$STDOUT[$i] .= "V" if ($opt{v});
					$tryMe++;
				}
				$STDOUT[$i] .= "LAN #] " if ($opt{v});
				$DATA[$i] .= $vlanCounter;
				$tryMe = 1;
			}

			# VLAN 103 Count
			$STDOUT[$i] .= "["  if ($opt{v});
			my $vlan103;
			while ( !length($vlan103) and $tryMe <= $maxTry) {
				$vlan103 = parseVlan103($t, $vendorName);
				$STDOUT[$i] .= "V" if ($opt{v});
				$tryMe++;
			}
			$STDOUT[$i] .= "LAN 103] " if ($opt{v});
			$DATA[$i] .= $vlan103;
			$tryMe = 1;

			# Available MAC Address on BNG
			$STDOUT[$i] .= "["  if ($opt{v});
			my $bngMAC;
			while ( !length($bngMAC) and $tryMe <= $maxTry) {
				$bngMAC = parseBNGMac($t, $vendorName);
				$STDOUT[$i] .= "B" if ($opt{v});
				$tryMe++;
			}
			$STDOUT[$i] .= "NGMAC] " if ($opt{v});
			$DATA[$i] .= $bngMAC;
			$tryMe = 1;

			# Uptime
			$STDOUT[$i] .= "["  if ($opt{v});
			my $uptimeResult;
			while ( !length($uptimeResult) and $tryMe <= $maxTry) {
				$uptimeResult = parseUptime($t, $vendorName);
				$STDOUT[$i] .= "T"  if ($opt{v});
				$tryMe++;
			}
			$tryMe = 1;
			# print "($uptimeResult ";
			my $formattedUptime = formatUptime($uptimeResult);
			# print $formattedUptime." )";
			$DATA[$i] .= "\"".$formattedUptime;
			push(@uptimes, uptimeInMinutes($formattedUptime));
			if (uptimeInMinutes($formattedUptime) lt 0) {
				$DATA[$i] .= " ( ERROR: ".uptimeInMinutes($formattedUptime)." | ".$formattedUptime." )";
			}
			$DATA[$i] .= "\";";
			$nodes{$targets[$i]} = uptimeInMinutes($formattedUptime);
			$STDOUT[$i] .= "IME] " if ($opt{v});

			# Neighborhood Discovery
			$STDOUT[$i] .= "["  if ($opt{v});
			my $neighborhood;
			while ( !length($neighborhood) and $tryMe <= $maxTry) {
				$neighborhood = &parseNeighborhood($t, $vendorName, $targets[$i]);
				$STDOUT[$i] .= "G" if ($opt{v});
				$tryMe++;
			}
			$STDOUT[$i] .= "RAPH] " if ($opt{v});
			$DATA[$i] .= $neighborhood;
			$tryMe = 1;

			if ( $opt{a} ) {
				$aclCount = 0;
				# ACL List Compliancy Check
				$DATA[$i]   .= "\"";
				foreach my $firstKey ( keys %aclList ) {										# Vendor Name
					if ( $firstKey eq $vendorName ) {
						$STDOUT[$i] .= "[ACL " if ($opt{v});
						foreach my $secondKey ( keys %{$aclList{$firstKey}} ) {					# ACL List Name
							my $aclCompliancyCheck;
							$aclCount++;
							$tryMe = 1;
							while ( !length($aclCompliancyCheck) and $tryMe <= $maxTry) {
								$aclCompliancyCheck = checkACLCompliancy($t, $vendorName, $secondKey, \@{$aclList{$firstKey}{$secondKey}});
								$STDOUT[$i] .= $aclCount if ($opt{v});
								$DATA[$i]   .= $aclCompliancyCheck    unless ( $aclCompliancyCheck eq 1 );
								$tryMe++;
							}
						}
						$STDOUT[$i] .= "] " if ($opt{v});
					}
				}
				$DATA[$i]   .= "\";";
				$tryMe = 1;
			}

			# UPS Existance
			if ( in_array(\@upslist, $ciName) ) {
				$STDOUT[$i] .= "[UPS] " if ($opt{v});
				$DATA[$i]   .= "Yes;";
			} else {
				$STDOUT[$i] .= "[!UPS] " if ($opt{v});
				$DATA[$i]   .= "No;";
			}

			$DATA[$i]   .= "\n";      # Add a new line at the end of the line
		} else {
			$STDOUT[$i] .= "(Username/Password Problem) " if ($opt{v});
		}
		disconnect($t);
		$STDOUT[$i] .= "D"  if ($opt{v});
	} else {
		$STDOUT[$i] .= "Could not initiate a TCP Session on port 23";
	}

	print $STDOUT[$i];
	print "\n" if ($opt{v});

	return;
}


sub checkACLCompliancy() {
	my $obj = shift;
	my $vendor = shift;
	my $aclListName = shift;
	my @aclList = shift;

	my $output = "";
	if ( $vendor eq "huawei" ) {
		$cmd = 'disp current conf '.$aclListName.' | e #'; $prompt = '/<.*>$/'; $regex = '(.*)'; $removeRegEx = '\(\d* matches\)';
	} elsif ( $vendor eq "cisco" ) {
		$cmd = 'sh access-list '.$aclListName.' | e Extended'; $prompt = '/#$/'; $regex = '(.*)'; $removeRegEx = '\(\d* matches\)';
	}
	#print "Running $cmd\n";
	my @return = $obj->cmd(String => $cmd, Prompt => $prompt );

	my $missingCount = 0;
	my @tempArray;
	foreach my $line (@return) {
		$line =~ s/$removeRegEx//;		# Remove matches thing
		$line =~ s/^\s*//;				# Left and right trim
		chomp($line);
		$line =~ s/\s*$//;				# Left and right trim
		if ( $line =~ /nw.*/) { $line = ""; }
		if ( length($line) ) {
			if ( $line =~ /$regex/ ) {
				push(@tempArray, $1);
				if ( !in_array(\@{$aclList[0]}, $1) ) {
					$missingCount++;
					# print "DEBUG: '$1' additional config on NE!\n";
				}
			}
		}
	}
	if ( $missingCount ) {
		$output .= $aclListName.": ".$missingCount." additional line on NE!\n";
	}

	$missingCount = 0;
	foreach my $line (@{$aclList[0]}) {
		#print "ON CONF : '$line'\n";
		if ( !in_array(\@tempArray, $line) ) {
			$missingCount++;
			#print "DEBUG: '$line' missing config on NE!\n";
		}
	}

	if ( $missingCount ) {
		$output .= $aclListName.": ".$missingCount." missing line on NE!\n";
	}

	if ( length($output) ) { return $output; } else { return 1; }
}

sub parseNeighborhood() {
	my $obj = shift;
	my $vendor = shift;
	my $myOwnIP = shift;

	my $output = "";

	my $cmd; my $prompt; my $regex;
	if ( $vendor eq "cisco" ) {
		$cmd = 'sh cdp neighbors detail | i IP'; $prompt = '/#$/'; $regex = '\s*IP address: (.*)';
	} elsif ( $vendor eq "huawei" ) {
		$cmd = 'dis lldp neighbor | i Management'; $prompt = '/<.*>$/'; $regex = 'Management address       : (.*)';
	}
	my @return = $obj->cmd(String => $cmd, Prompt => $prompt );

	my @ipList;
	foreach my $line (@return) {
		if ( $line =~ /$regex/ ) {
			push(@ipList, $1);
			# print "(! $1 )";
		}
	}
	my @uniqIPList = uniq(@ipList);
	$out = "\"";
	foreach my $ip (@uniqIPList) {
		# print "(+ $ip)";
		$out .= "$ip\n";
		if ($nodes{$ip}) {
			unless ( in_array(\@targets, $ip) ) {
				$nodes{$ip} = "NEIGHBOR";
			}
		} else {
			$nodes{$ip} 	= 0;
		}

		if ( !$edges{$ip."-".$myOwnIP} ) {
			$edges{$myOwnIP."-".$ip} = 'none';
		}

	}
	$out .= "\";";
	return $out;
}

sub parseBNGMac() {
	my $obj = shift;
	my $vendor = shift;

	my $out = "";

	my $cmd; my $prompt; my $regex;
	if ( $vendor eq "cisco" ) {
		$cmd = 'sh mac address-table | i 0030'; $prompt = '/#$/'; $regex = '\d*\s+0030\.*';
	} elsif ( $vendor eq "huawei" ) {
		$cmd = 'display mac-address | i 0030'; $prompt = '/<.*>$/'; $regex = '^0030.*';
	}
	my @return = $obj->cmd(String => $cmd, Prompt => $prompt );

	my $count = 0;
	foreach my $line (@return) {
		if ( $line =~ /$regex/ ) {
			$count++;
		}
	}
	$out .= $count.";";

	return $out;
}

sub parseVlan103() {
	my $obj = shift;
	my $vendor = shift;

	my $out = "";

	my $cmd; my $prompt; my $regex;
	if ( $vendor eq "cisco" ) {
		$cmd = 'show ip igmp snooping querier | i 103'; $prompt = '/#$/'; $regex = '^103\s*.*';
	} elsif ( $vendor eq "huawei" ) {
		$cmd = 'display igmp-snooping router-port vlan 103'; $prompt = '/<.*>$/'; $regex = 'VLAN 103, \d* router-port\(s\)';
	}
	my @return = $obj->cmd(String => $cmd, Prompt => $prompt );

	foreach my $line (@return) {
		if ( $line =~ /$regex/ ) {
			$out .= "\"Ok\";";
		}
	}

	return $out;
}

sub parseAvailableVlan() {		# Only applicable for Cisco Devices
	my $obj = shift;


	my @return = $obj->cmd(String => "sh mac address count | i Space", Prompt => '/#$/' );

	my $out = "";

	foreach my $line (@return) {
		if ( $line =~ /Total Mac Address Space Available: (\d*)/ ) {
			$out .= "\"".$1."\";";
		}
	}

	return $out;
}

sub parseUptime () {
	my $obj = shift;
	my $vendor = shift;

	my $out = "";

	my $cmd; my $prompt; my $regex;
	if ( $vendor eq "cisco" ) {
		$cmd = 'sh ver | i uptime'; $prompt = '/#$/'; $regex = '.* uptime is (.*)';
	} elsif ( $vendor eq "huawei" ) {
		$cmd = 'disp ver'; $prompt = '/<.*>$/'; $regex = '.* : uptime is (.*)';
	}
	my @return = $obj->cmd(String => $cmd, Prompt => $prompt );

	foreach my $line (@return) {
		if ( $line =~ /$regex/ ) {
			$out .= "\"".$1."\";";
		}
	}

	return $out;
}

sub disconnect() {
	my $obj			= shift;

	$obj->close();
	return 1;
}

sub authenticate() {
	my $obj 		= shift;
	my $username	= shift;
	my $password	= shift;
	my $vendor	  	= shift;

	my @initialCommands;

	my $prompt;
	if ( $vendor eq "cisco" ) {
		$prompt = '/#$/';
		$initialCommands[0] = "terminal length 0";
	} elsif ( $vendor eq "huawei" ) {
		$prompt = '/<.*>$/';
		#$initialCommands[0] = "user-interface vty 0 4";
		$initialCommands[0] = "screen-length 0 temporary";
	}

	if ( $obj->login( Name => $username,  Password => $password ,Prompt => $prompt ) ) {

		# Fixing screen buffering problems
		foreach my $command (@initialCommands) {
			$obj->cmd(String => $command, Prompt => $prompt);
		}
		return 1;
	} else {
		return 0;
	}
}

sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

sub formatUptime {
	my $string = shift;
	my $output;

	if ( $string =~ /(\d*) [year|s]*, (\d*) [month|s]*, (\d*) [week|s]*, (\d*) [day|s]*, (\d*) [hour|s]*, (\d*) [minute|s]*/ ) {
		$output = sprintf("%02s %02s:%02s", ($5+($3*7)+($2*30)+$1*365), $5, $6);
	} elsif ( $string =~ /(\d*) [month|s]*, (\d*) [week|s]*, (\d*) [day|s]*, (\d*) [hour|s]*, (\d*) [minute|s]*/ ) {
		$output = sprintf("%02s %02s:%02s", ($3+($2*7)+($1*30)), $4, $5);
	} elsif ( $string =~ /(\d*) [week|s]*, (\d*) [day|s]*, (\d*) [hour|s]*, (\d*) [minute|s]*/ ) {
		$output = sprintf("%02s %02s:%02s", ($2+($1*7)), $3, $4);
	} elsif ( $string =~ /(\d*) [day|s]*, (\d*) [hour|s]*, (\d*) [minute|s]*/ ) {
		$output = sprintf("%02s %02s:%02s", $1, $2, $3);
	} elsif ( $string =~ /(\d*) [hour|s]*, (\d*) [minute|s]*/ ) {
		$output = sprintf("00 %02s:%02s", $1, $2);
	} elsif ( $string =~ /(\d*) [minute|s]*/ ) {
		$output = sprintf("00 00:%02s", $1);
	} else {
		$output = "N/A";
	}

	return $output;
}

sub uptimeInMinutes {
	my $string = shift;
	my $output = -1;

	if ( $string =~ /(\d*) (\d*):(\d*)/) {
		$output = (($1*1440)+($2*60)+$3);
	}
	return $output;
}

sub gradient {
    my $min = shift;
	my $max = shift;
	my $num = shift;

    my $middle = ( $min + $max ) / 2;
    my $scale = 255 / ( $middle - $min );

    return "FF0000" if $num <= $min;    # lower boundry
    return "00FF00" if $num >= $max;    # upper boundary

    if ( $num < $middle ) {
        return sprintf "FF%02X00" => int( ( $num - $min ) * $scale );
    } else {
        return sprintf "%02XFF00" => 255 - int( ( $num - $middle ) * $scale );
    }
}

sub in_array {
     my ($arr,$search_for) = @_;
     my %items = map {$_ => 1} @$arr;
     return (exists($items{$search_for}))?1:0;
}

sub usage {
		my $usageText = << 'EOF';

This script connects to IPs that are given as input file, then parses the output for relative commands.

Author            Emre Erkunt
                  (emre.erkunt@gmail.com)

Usage : fetchFromNetwork [-i INPUT FILE] [-v] [-o OUTPUT FILE] [-u USERNAME] [-p PASSWORD] [-t THREAD COUNT] [-g] [-a ACL FILE] [-n]

Example INPUT FILE format is ;
------------------------------
Ci Name;IpAddress
nw_sf_s033_a1.34_byld_vatan212sokak_yukseloglug_7_7;172.28.191.196
nw_sf_s033_a1.34_byld_yesil_a_6;172.28.191.194
nw_sf_s033_a1.34_byld_yesil_a_7;172.28.191.193
------------------------------

 Parameter Descriptions :
 -i [INPUT FILE]        Input file that includes IP addresses
 -o [OUTPUT FILE]       Output file about results
 -u [USERNAME]          Given Username to connect NEs
 -p [PASSWORD]          Given Password to connect NEs
 -a [ACL FILE]          ACL File that you would like to compare with.
 -n                     Skip self-updating
 -t [THREAD COUNT]      Number of threads that should run in parallel      ( Default 2 threads )
 -g                     Generate network graph                             ( Default OFF )
 -v                     Disable verbose                                    ( Default ON )

EOF
		print $usageText;
		exit;
}   # usage()
