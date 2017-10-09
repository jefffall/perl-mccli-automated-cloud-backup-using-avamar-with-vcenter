#!/usr/bin/perl
# 
# Jeffrey Fall
# 
# VMDK Backup
##
# Updated 2.18.2015
#

########################################################
# Included Perl Modules
########################################################
#use String::Util;
use Net::Ping;
use List::Util 'first';

#use Net::SSH::Perl;
#
#use diagnostics;
#

###########################################################################################
#
# Operations configuration section.
#
# Add prefixes to be backed up here into the list. The list will sequence through looking
# for matches of the name substring. For example: to backup all of the machines beginning
# with hlxtil just add hxtil and any VM with hlxtil in the VM name will be backed up.
#
# Windows list of VM's to backup:
#
@WINDOWS_PARTIAL_NAMES = "CAHYWR1ENGVM501";
#
# Linux list of VM's to backup
#
@LINUX_PARTIAL_NAMES = "hlxtil0500";
#
#
###########################################################################################








#
############################################################################################
# Purpose: Provide VMDK backup from Vcenter Cluster of Windows and Linux VM's
#
# This Perl Program is a collection of perl subroutines to allow the automated backup
# of VM's located on VMware vCenters. The VMware vCenters are registered with the Avamar grid
# and are accessible via an installed authentication certificate.
#
# As such this program will only work under very strict conditions:
#
#  1) The vCenter must be registered with the Avamar grid and a Certificate installed.
#
#
# INPUTS:
#
# The script gathers information about the vCenters and proxies attached to an Avamar Grid via
# the EMC proxycp java jar.
#
# The OPS team may customize the prefixes or suffix of linux or Windows host names for the script
# to search for on the Vcenters for backup.
#
# Outputs:
#  Datasets for the VM being protected.
#  Group for the VM being protected.
#  An on demand backup job kicked off for the VM being protected.
#
#############################################################################################

#############################################################################################
#
# Utility Routines - Array Operations
#
#############################################################################################
#Perl subroutines for perl array operations. Borrowed from ARRAY::Util.pm

sub unique(@) {
	return keys %{ { map { $_ => undef } @_ } };
}

sub intersect(\@\@) {
	my %e = map { $_ => undef } @{ $_[0] };
	return grep { exists( $e{$_} ) } @{ $_[1] };
}

sub array_diff(\@\@) {
	my %e = map { $_ => undef } @{ $_[1] };
	return @{
		[
			( grep { ( exists $e{$_} ) ? ( delete $e{$_} ) : (1) } @{ $_[0] } ),
			keys %e
		]
	  };
}

sub array_minus(\@\@) {
	my %e = map { $_ => undef } @{ $_[1] };
	return grep( !exists( $e{$_} ), @{ $_[0] } );
}


########################################################################################
# Debugging debuger
########################################################################################

sub debug
{
	if ($DEBUG == 1)
	{
		print "$_[0]";
		
	}
}






########################################################################################
# return number of elements in array
##############################################$#########################################
sub num_ele {
	my $count = 0;

	#debug "number of elements in array: processing array: @{$_[0]}\n";
	foreach ( @{ $_[0] } ) {
		$count++;

		#	debug "$count: $_\n"
	}

	return $count;
}

########################################################################################
# perl trim
##############################################s#########################################

# perl trim function - remove leading and trailing whitespace
sub trim($) {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

########################################################################################
# Operations team custom section
#
# Edit Variables in this section to reflect the operational enviroment.
#
# For example: add in FQDN's for Avamar Grids, vCenter's and Avamar Proxies
#
########################################################################################
#
#
# Add cloud domain here
$DOMAIN = "cloud";

#
# Add list of vCenter's here. Only one Vcenter is also OK.
# For now the Vcenter server in the datecenter
# Below is a Perl Array of Vcenters

# Avamar Grid this program is running on.
# Note - if this program is running on an mccli server then this area contains the Avamar GRIDS
# of interest
@AVAMAR_GRIDS = ("youravamar.yourcompany.com");

########################################################################################
# Process error codes
########################################################################################

sub process_error_code

{
# mccli dataset add	
#	22219 Dataset created.
# 23008 Dataset already exists.

################## mccli client add #####################
#22210 Client successfully added.
#22238 Client exists.
#22263 Client registration error.
#22288 Dataset does not exist.
#22289 Retention policy does not exist.
#22558 A domain or client with this name already exists.
#23012 Invalid encryption method specified on the CLI.
#30922 Failed to connect to vCenter.

}


########################################################################################
# Subroutine print time
########################################################################################


sub print_time
{
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();


	printf("%02d:%02d:%02d ", $hour, $min, $sec);
}


########################################################################################
# Subroutine log time
##############################################s#########################################


sub log_time
{
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();


	printf LOGFILE  ("%02d:%02d:%02d ", $hour, $min, $sec);
}

########################################################################################
# Check vcenter Connections
########################################################################################

sub check_vcenter_connections

{
	
my	$status = `/usr/local/avamar/bin/mccli server show-services`;
	
		
	if ($status =~ /All vCenter connections OK./)
	    { 
				return 1;
	    }
	else
	    {
	   debug "Vcenter connections are DOWN from Grid $HOSTNAME to vCenter(s). Please restore vCenter Connections. Script has halted\n";
	print_time; print "Vcenter connections are DOWN from Grid $HOSTNAME to vCenter(s). Please restore vCenter Connections. Script has halted\n     ";
	log_time; print LOGFILE "Vcenter connections are DOWN from Grid $HOSTNAME to vCenter(s). Please restore vCenter Connections. Script has halted\n     ";
	
	    die  "Vcenter connections are DOWN from Grid $HOSTNAME to vCenter(s). Please restore vCenter Connections. Script has halted\n";
	    }
}





########################################################################################
# Subroutine: init_envrironment()
########################################################################################
sub init_environment() {
	
my	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

my $logfilename = sprintf("> imageBU-%04d%02d%02d-%02d-%02d-%02d ", $year+1900, $mon+1, $mday, $hour, $min, $sec);

print "Log file name = $logfilename\n";
	
	
open(LOGFILE, $logfilename ) or die "Could not open file '$filename' $!";

	#debug "\nInitializing the $DATACENTER backup vmdk environment\n";
	#
	# Get the hostname of the Avamar Grid
	$HOSTNAME = `hostname`;
	$HOSTNAME =~ s/\r\n//;  # remove trailing line feed; # remove trailing cr/lf

	#
	#
	#ping_environment();
	#
	# Select all the data sources in the proxies
	
	print "Backup VMDK script started on Avamar Grid $HOSTNAME\n";
	
	
	
	debug "Checking vCenter connections to this Avamar Grid $HOSTNAME\n";
	print_time; print "Checking vCenter connections to this Avamar Grid $HOSTNAME     ";
	log_time; print LOGFILE "Checking vCenter connections to this Avamar Grid $HOSTNAME     ";
	
	my $status = check_vcenter_connections;
	
	if ($status == 1)
	{
	debug "vCenter OK and GOOD on this Avamar Grid $HOSTNAME\n";
	print_time; print "vCenter connections OK and GOOD on this Avamar Grid $HOSTNAME     ";
	log_time; print LOGFILE "vCenter connections OK and GOOD on this Avamar Grid $HOSTNAME     ";
	
	}
	else
	{
		debug "vCenter connections BAD on this Avamar Grid $HOSTNAME\n";
	print_time; print "vCenter connections BAD on this Avamar Grid $HOSTNAME     ";
	log_time; print LOGFILE "vCenter connections BAD on this Avamar Grid $HOSTNAME     ";
	
		
	}
	
	
	
	
	debug "Status Initialize - Enable all Proxy Data sources\n\n";
	print_time; print "Selecting All Data Sources on Proxy(s)     ";
	log_time; print LOGFILE "Selecting All Data Sources on Proxy(s)     ";
	
	my $status =
	  `/usr/bin/java -jar /home/jfall/proxycp.jar --selectalldatastore`;
	debug "\n\n";
    print "DONE\n";
	return (0);
}



########################################################################################
# Subroutine ping
##############################################s#########################################
sub ping {
	my $host = $_[0];

	#  my ($host) = @_;

	$p = Net::Ping->new('icmp');

	#debug "Pinging host: $host\n";
	#debug "      $host is alive.\n" if $p->ping($host) else "$host is dead.\n";
	if ( $p->ping($host) ) {
		debug "       $host is alive.\n";
	}
	else {
		debug "       $host is DOWN. Please investigate.\n";
	}

	$p->close();
}

########################################################################################
# ping_environment
########################################################################################
sub ping_environment {

	#
	debug "   Pinging VCenters...\n";

	# ping the vCenters
	#debug "Testing the vCenter List for $DATACENTER\n";
	foreach (@VCENTERS) {
		ping($_);
	}

	debug "   Pinging Avamar Grids...\n";

	# ping the Avamar Grid(s)
	#debug "Testing the Avamar Grid(s) for $DATACENTER\n";
	foreach (@AVAMAR_GRIDS) {
		ping($_);
	}

	debug "   Pinging Avamar Proxies\n";

	# ping the Avamar Prox(y)(ies)
	#debug "Testing the Avamar Proxy(y)(ies) for $DATACENTER\n";
	foreach (@PROXIES) {
		ping($_);
	}

	#debug "\n";

}

########################################################################################
# Path to VMDK
#
# Input: String path to vmdk
#
# Outputs: Full path to the vmdk in the form [device] path
#          Where path is of the form:
#          name of vm / name of vm.vmdk
#
#          Example vmdk path:  [FC002] hlxtil0500/hlxtil0500.vmdk
########################################################################################

sub pathtovmdk {
	my $vm_for_path = ${ $_[0] };

	my @output =
`java -jar /home/jfall/proxycp.jar --listpermission --vm $vm_for_path --force`;

	my @line = grep /Attempting to read VMX File/, @output;
	my $someline = join( ' ', @line );
	my @stuff = split( ' ', $someline );

	my @splitonfolder = split( '/folder/', $stuff[9] );

	my @vmdkpath = split( '.vmx', $splitonfolder[1] );

	my @splitonequals = split( '=', $vmdkpath[1] );

	my $fullpath = "[" . $splitonequals[2] . "]" . " " . $vmdkpath[0] . ".vmdk";

	return $fullpath;
}

########################################################################################
# Path to VMDK_1 - the 2nd hard disk (windows d:\)
# This is the path to the 2nd hard disk if present. Usually present in windows servers.
#
# Input: String path to vmdk_1
#
# Outputs: Full path to the vmdk in the form [device] path
#          Where path is of the form:
#          name of vm / name of vm.vmdk
#
#          Example vmdk path:  [FC002] hlxtil0500/hlxtil0500.vmdk
########################################################################################

sub pathtovmdk_1 {

	my $vm_for_path = ${ $_[0] };

	my @output =
`java -jar /home/jfall/proxycp.jar --listpermission --vm $vm_for_path --force`;

	my @line = grep /Attempting to read VMX File/, @output;
	my $someline = join( ' ', @line );
	my @stuff = split( ' ', $someline );

	my @splitonfolder = split( '/folder/', $stuff[9] );

	my @vmdkpath = split( '.vmx', $splitonfolder[1] );

	my @splitonequals = split( '=', $vmdkpath[1] );

	my $fullpath =
	  "[" . $splitonequals[2] . "]" . " " . $vmdkpath[0] . "_1" . ".vmdk";

	return $fullpath;
}

########################################################################################
# get_registered_vcenters  - gets a list of VCenters attached to the Avamar Grid
# via the EMC proxycp.jar. Note: proxycp.jar is not installed on the Avamar Grid by default
# and must be hand installed into a java CLASS_PATH
########################################################################################
sub get_registered_vcenters

{
	@registered_vcenters_raw =
	  `/usr/bin/java -jar /usr/local/avamar/lib/proxycp.jar -envinfo`;

	my @registered_vcenters = grep /Vcenter Name/, @registered_vcenters_raw;

	foreach (@registered_vcenters) {
		$_ =~ s/: //;              # Remove ": "
		$_ =~ s/Vcenter Name//;    # Remove "Vcenter Name"
		$_ = trim($_);             #remove leading spaces
		$_ =~ s/\r\n//;
		;                          # remove trailing line feed
	}

	return (@registered_vcenters);
}

########################################################################################
# name_filter - filters on a name prefix or suffix
########################################################################################
sub name_filter

{
	my $keyword     = ${ $_[0] };
	my @names_array = @{ $_[1] };

	my @filtered_names = grep /$keyword/, @names_array;
	return (@filtered_names);
}

########################################################################################
# get_raw_client_output_from_vcenter
########################################################################################

sub get_raw_client_output_from_vcenter

{
	my $vcenter = ${ $_[0] };

# Walk the clients in a list of vcenters which is passed in as the first arg  with this mccli command...
# mccli vcenter browse --name=cahywr1engvca05.itservices.yourcompany.com --type=VM --recursive
#
# Run the mccli command and Put the output of the command into an array.
#
#

	@vcenter_clients = '';

	debug "    Scanning Vcenter  $vcenter for clients now...\n";

	#
	@raw_clients = `mccli vcenter browse --name=$vcenter --type=VM --recursive`;
	push( @vcenter_clients, @raw_clients );

	debug "Returning RAW clients list from all vcenters\n\n";
	return (@vcenter_clients);

}

########################################################################################
# Get client folder path.
#
# This sub exists primarily to get the folder path for an mccli add client command.
#
# The mccli client add requires a folder path. The folder path can be found from
# an mccli browse vcenter command
#
# Input: Raw list of clients from mccli vcenter browse
# Input: client to name find the vcenter which hosts it.
#
# Gets the data center which is hosting the client.
#
# Input is the raw list of clients from a mccli browse data center
# Input is also the client of interest
########################################################################################

sub get_client_folder_path

{
	my @raw_clients = @{ $_[0] };
	my $client      = ${ $_[1] };

	my $datacenter_raw = first { /$client/ } @raw_clients;

	my $loc1 = index( $datacenter_raw, "/vm" );
	my $loc2 = index( $datacenter_raw, $client, $loc1 + 1 );
	debug
"\nAvamar Script Error sub get_client_folder Path Client is not found. Can not parse string\n"
	  if $loc2 < 0;

	my $folder_path_raw = substr( $datacenter_raw, $loc1, $loc2 - $loc1 );

	my @folder_path = split( '/vm', $folder_path_raw );

	return ( $folder_path[1] );
}

########################################################################################
# Get hosting data center.
#
# This sub exists primarily to get the hosting data center for a
# for a client we wish to image backup with an mccli add client command.
# We first need to add the client for image backup before it is backed up.
#
# The mccli client add requires a datacenter hosting the client.
# The hosting datacenter can be found from
# an mccli browse vcenter command
#
#
# Input: Raw list of clients from mccli vcenter browse
# Input: client to name find the vcenter which hosts it.
#
# Gets the data center which is hosting the client.
#
# Input is the raw list of clients from a mccli browse data center
# Input is also the client of interest
########################################################################################

sub get_hosting_data_center

{
	my @raw_clients = @{ $_[0] };
	my $client      = ${ $_[1] };

	my $datacenter_raw = first { /$client/ } @raw_clients;
	my @browse_vcenter_output = split( ' ', $datacenter_raw );

	my @data_center_and_folder = split( '/', $browse_vcenter_output[3] );

	my $datacenter = $data_center_and_folder[1];
	return ($datacenter);
}

########################################################################################
# get_vcenter_fqdn
# Returns the whole vCenter FQDN name given the name of the vcenter.
# This is needed in the --domain arg of the mccli add client command
########################################################################################

sub get_vcenter_fqdn {

	my @vcenter      = @{ $_[0] };
	my $vcenter_fqdn = "qwertyasdfg";

	foreach (@vcenter) {
		debug "processing vcenter: $_\n";
		my $vcenter_fqdn = first { /$_/ } @registered_vcenters_raw;
		if ( $vcenter_fqdn != "qwertyasdfg" ) {
			last;
		}
	}
	debug "get_vcenter_fqdn: fqdn of the vcenter = $vcenter_fqdn\n";
}

########################################################################################
# get_clients_from_vcenter (get clients from ONE Vcenter)
#
# Input - A string representing a vcenter
#
# Returns: Array of clients found on the vCenter.
#
# Calling example: get_clients_from_vcenter(\"Some_vcenter_name")'
########################################################################################
sub get_clients_from_vcenter {

	my $vcenter = ${ $_[0] };

	debug "    Scanning Vcenter  $vcenter for clients now...\n";
	@vcenter_clients = '';

	#
	@raw_clients = `mccli vcenter browse --name=$vcenter --type=VM --recursive`;
	splice @raw_clients, 0, 3;
	$row = 0;
	foreach (@raw_clients) {
		@temp = split( ' ', $_ );
		$vcenter_clients[ $row++ ] = $temp[0];
	}
	pop(@vcenter_clients)
	  ;    # Last element of the array looks to be blank so remove it.

	return (@vcenter_clients);
}

########################################################################################
# get_backup_clients_from_domain
########################################################################################
sub get_backup_clients_from_domain {

# Walk the clients in a domain which is passed in as the first arg  with this mccli command...
#  mccli client show --recursive --domain=$domain
#
# Run the mccli command and Put the output of the command into an array.
#
#
	@clients_to_backup = '';

	#
	#my ($domain) = @_;
	my $domain = ${ $_[0] };
	@raw_clients = `mccli client show --recursive --domain=$domain`;
	splice @raw_clients, 0, 3;
	debug "\n";

	#
	$row = 0;
	foreach (@raw_clients) {
		@temp = split( ' ', $_ );
		$clients_to_backup[ $row++ ] = $temp[0];
	}
	return (@clients_to_backup);
}

###########################################################################
#  get datasets subroutine
#  This subroutine gets datasets from the Domain passed in as arg 0.
###########################################################################

sub get_datasets {
	my ($domain) = @_;

	my @raw_datasets = `mccli dataset show --recursive --domain=$domain`;
	splice @raw_datasets, 0, 3;

	@datasets = '';
	$x        = 0;

	foreach (@raw_datasets) {
		@temp = split( ' ', $_ );
		@datasets[$x] = @temp[0];
		$x = $x + 1;
	}
	return (@datasets);
}

###########################################################################
#  register_clients_for_image_backup
#
#  This subroutine will take a array (list) of clients to be added to the
#  VirtualMachines folder on a vCenter for image backup and add the clients
#  To the /(Vcenter FQDN)/VirtualMachines folder / domain
#
#  Once a VM is added to VirtualMachines folder off of a vCenter then
#  the VM may be backed up with an Image Backup
###########################################################################

# In the datacenter Avamar - there are multiple datacenters.
# First we get a list of the clients
sub register_clients_for_image_backup {

# reference working command	example
# mccli client add --mcsuserid=MCUser --mcspasswd=MCUser1 --name=hlxtil0500 --changed-block-tracking=true --type=vmachine --domain=/cahywr1engvca05.itservices.yourcompany.com/VirtualMachines --datacenter=/vTIL_Hayward --folder='/vTIL/INFRASTRUCTURE vTIL'

	my @clients      = @{ $_[0] };    # Clients
	my $vcenter_FQDN = ${ $_[1] };    # Vcenter

	my @raw_clients = get_raw_client_output_from_vcenter( \$vcenter_FQDN );

	foreach (@clients) {
		debug
		  "%register_client_for_image_backup%: register client named: $_\n)";
		  print_time; print "Registering VM $_ to this Avamar Grid     ";
		  log_time; print LOGFILE "Registering VM $_ to this Avamar Grid     ";

		# Get the datacenter which belongs to the client
		my $datacenter_used = get_hosting_data_center( \@raw_clients, \$_ );
		debug "Datacenter for client $_ = $datacenter_used\n";

		# Get client folder path
		my $folder_used = get_client_folder_path( \@raw_clients, \$_ );
		chop($folder_used);    # remove the trailing /

		debug "Folder used for client $_ = $folder_used\n";

		# Get FQDN name of the vCenter

		debug "Vcenter FQDN = $vcenter_FQDN\n";

		my $command =
"mccli client add --name=$_ --changed-block-tracking=true --type=vmachine --domain=/$vcenter_FQDN/VirtualMachines --datacenter=/$datacenter_used --folder='$folder_used'";

		debug
"Registering Client: $_ from vCenter $vcenter_FQDN for image backup on Avamar Grid now...\n\n";
		debug "Issuing command to register now: $command\n\n";

		$status = `$command`;
		debug "Client $_ registeration status is: $status\n\n";
		print "DONE\n";

	}
}







#######################################################################################
#
# Returns a list of proxies registered to the Avamar grid which the cpproxy command
# is run on.
#
########################################################################################

sub get_proxies

{
	my $all_proxies =
	  `/usr/bin/java -jar /home/jfall/proxycp.jar --listproxy --all`;

	my @only_proxies = split "\n", $all_proxies;

	my @my_proxies = grep /-proxy-/, @only_proxies;

	return (@my_proxies);
}

#######################################################################################
#  Create VM Image Backup
#
#
#  This subroutine readies the data structures on the Avamar to get a backup ready to go.
#  The backup is kicked off from the group.  In this case, a group contains one dataset
#  and the dataset contains the path to the .vmdk file for the particular VM.
#
#  Only the first disk - or Hard Disk 1 is backed up for a linux machine as per
#  specified requirements.
#
#  Steps:
#  1) Get the name of the data source to create the path to the .vmdk
#  2) Get all the proxy names to add to the group
#  3) Create the dataset.
#  4) Add the .vmdk paths to the dataset.
#       There is one .vmdk path for C:\ disk and one for D:\ disk on Windows Server
#  5) Create the group for this one VM.
#  6) Add the client (VM) to the group
#  7) Add the proxy to the group
#  8) Add the schedule to the group
#
#  Result: The group will be able to be backed up via an on-demand backup or via schedule
#  Inputs:
#  a) VM or Client to back up: example: hlxtil0500 (must reside on the vCenter)
#  b) vCenter FQDN!!! example: (just like this) cahywr1engvca05.itservices.yourcompany.com
#  c) "window" as VM type. any other type will be treated as linux. This is for the number of datasets.
#     1 dataset for Linux. Two for windows server.
#  d) @proxies is passed in via MAIN as a global (well not really passed in)
#
#  Output:
#  a) A dataset will be created as name of VM or client appended wiht -HD1. Example: hlxtil0500-HD1 for Disk c:\ and -HD2 for Disk D:\
#  b) A group will be created as name of the VM or client appended with -GP. Example: hlxtil0500-GP
#
#  Calling example: image_backup_vm(\"CAHYWR1ENGVM501", \"cahywr1engvca05.itservices.yourcompany.com", \"windows");
#
#######################################################################################

sub image_backup_vm

{
	my $vm         = ${ $_[0] };
	my $vcenter    = ${ $_[1] };
	my $type_of_vm = ${ $_[2] };
	
	my $avamar_plugin_type = 1016;

	#
	debug "\nDebug - type of VM = $type_of_vm\n\n";
	debug " \n";

if ($type_of_vm eq "windows")
  {
  $avamar_plugin_type=3016;
  }
  
 elsif ($type_of_vm eq "linux")
  {
  $avamar_plugin_type=1016;
  }
  
  else
  {
  	debug "ERROR: Image backup of VM Type $type_of_vm not supported!\n";
  	debug "type of vm must be one of windows or linux on command arg 2 called from main\n";
  	
  }
 
 my $message = "";

	# Create the first dataset
	debug "Create the dataset HD1\n";
	my $hd1 = $vm . "-HD1";
	debug "mccli dataset add --domain=$vcenter --name=$hd1\n";
	print_time; print "Creating Dataset $hd1 for $vm on $this_vcenter     ";
	log_time; print LOGFILE "Creating Dataset $hd1 for $vm on $this_vcenter     ";
	
	$status = `mccli dataset add --domain=$vcenter --name=$hd1`;
	if ($status =~ /22219/)
	  {
	  	 $message = "Dataset Created DONE";
	  }
	  elsif($status =~ /23008/)
	  {
	  	$message = "Dataset Already Exists! FAIL"
	  }
	
	print "Mccli create dataset status = $status\n";
	print "$message\n";
	debug "\n$status\n";

	#
	# The 2nd dataset is only created for a Microsoft Windows based server
	if ( $type_of_vm eq "windows" ) {
		debug "Windows VM Creating the 2nd dataset HD2\n";
		$hd2 = $vm . "-HD2";
		debug "mccli dataset add --domain=$vcenter --name=$hd2\n";
		print_time; print "Creating Dataset $hd2 for $vm on $this_vcenter     ";
		log_time; print LOGFILE "Creating Dataset $hd2 for $vm on $this_vcenter     ";
		$status = `mccli dataset add --domain=$vcenter --name=$hd2`;
		if ($status =~ /22219/)
	  {
	  	 $message = "Dataset Created DONE";
	  }
	  elsif($status =~ /23008/)
	  {
	  	$message = "Dataset Already Exists! FAIL"
	  }
			print "Mccli create dataset status = $status\n";
		print "$message\n";
		debug "\n$status\n";
	}

	debug " \n";
	debug
"Add target to dataset 1. This is the .vmdk file for the first hard disk\n";
	debug " \n";
	my $TargetNameHD1      = $vcenter . '/' . $vm . '-HD1';
	my $first_path_to_vmdk = pathtovmdk( \$vm );
	debug
"mccli dataset add-target --name=$TargetNameHD1 --plugin=$avamar_plugin_type --target=$first_path_to_vmdk";
    print_time; print "Adding target $first_path_to_vmdk to dataset $TargetNameHD1     ";
    log_time; print LOGFILE "Adding target $first_path_to_vmdk to dataset $TargetNameHD1     ";
	$status = `mccli dataset add-target --name=$TargetNameHD1 --plugin=$avamar_plugin_type --target=$first_path_to_vmdk`;
	
	if ($status =~ /22220/)
	  {
	  	 $message = "Dataset Modified DONE\n";
	  }
	  elsif($status =~ /23009/)
	  {
	  	$message = "Invalid plugin specified on the CLI. FAIL";
	  }
	  elseif ($status =~ /22288/)
	  {
	  	$message = "Dataset does not exist. FAIL";
	  }
	  elseif ($status =~ /23022/)
	  {
	  	$message = "Error parsing input file. FAIL";
	  }
	  elsif ($status =~ /23023/)
	  {
	  	$message "Input file could not be found. FAIL";
	  }
	  
	
	
	
	print "Dataset add target status = $status\n";
	print "$message\n";
	debug "\n$status\n";

	#
	debug " \n";
	if ( $type_of_vm eq "windows" ) {
		debug
"Add target to dataset 2. This is the .vmdk file for the 2nd hard disk\n";
		debug " \n";
		my $TargetNameHD2       = $vcenter . '/' . $vm . '-HD2';
		my $second_path_to_vmdk = pathtovmdk_1( \$vm );
		debug
"mccli dataset add-target --name=$TargetNameHD2 --plugin=$avamar_plugin_type --target=$second_path_to_vmdk\n";
print_time; print "Adding target $second_path_to_vmdk to dataset $TargetNameHD2     ";
log_time; print LOGFILE "Adding target $second_path_to_vmdk to dataset $TargetNameHD2     ";
		$status =
`mccli dataset add-target --name=$TargetNameHD2 --plugin=$avamar_plugin_type --target="$second_path_to_vmdk"`;

if ($status =~ /22220/)
	  {
	  	 $message = "Dataset Modified DONE\n";
	  }
	  elsif($status =~ /23009/)
	  {
	  	$message = "Invalid plugin specified on the CLI. FAIL";
	  }
	  elseif ($status =~ /22288/)
	  {
	  	$message = "Dataset does not exist. FAIL";
	  }
	  elseif ($status =~ /23022/)
	  {
	  	$message = "Error parsing input file. FAIL";
	  }
	  elsif ($status =~ /23023/)
	  {
	  	$message "Input file could not be found. FAIL";
	  }


print "Dataset add target status = $status\n";
		debug "\n$status\n";
		print "$message\n";
	}

	#
	debug " \n";
	debug "Create Group for $type_of_vm VM\n";

	#
	my $domain_temp     = $vcenter . '/VirtualMachines';
	my $group_name_temp = $vm . '-GP';
	
	
	if ( $type_of_vm eq "windows" )

# For a microsoft Windows Server use two datasets HD1 and HD2 for C:\ and D:\ drives respectively
	{
		debug
"mccli group add --dataset=$hd1 --dataset=$hd2 --dataset-domain=$vcenter --domain=$domain_temp  --enabled=true --name=$group_name_temp\n";
print_time; print "Creating a group called $group_name_temp which contains dataset $hd1 and dataset $hd2 on $vcenter for Windows VM     ";
log_time; print LOGFILE "Creating a group called $group_name_temp which contains dataset $hd1 and dataset $hd2 on $vcenter for Windows VM     ";

		$status =
`mccli group add --dataset=$hd1 --dataset=$hd2 --dataset-domain=$vcenter --domain=$domain_temp  --enabled=true --name=$group_name_temp`;

if ($status =~ /22207/)
	  {
	  	 $message = "New Group Created.  DONE\n";
	  }
	  elsif($status =~ /22233/)
	  {
	  	$message = "Group already exists. FAIL";
	  }
	  elseif ($status =~ /22235/)
	  {
	  	$message = "Group add failed. FAIL";
	  }
	  elseif ($status =~ /23003/)
	  {
	  	$message = "Invalid dataset name specified on the CLI. FAIL";
	  }
	  elsif ($status =~ /23004/)
	  {
	  	$message "Invalid schedule name specified on the CLI. FAIL";
	  }
 elsif ($status =~ /23005/)
	  {
	  	$message "Invalid retention policy name specified on the CLI. FAIL";
	  }
 elsif ($status =~ /23012/)
	  {
	  	$message "Invalid encryption method specified on the CLI. FAIL";
	  }
 elsif ($status =~ /31002/)
	  {
	  	$message "Group add or update failed due to a policy hierarchical management violation. FAIL";
	  }



print "group add status = $status";
		debug "\n$status\n";
		print "$message\n";
	}
	else

# else it is assumed a non-windows machiune which is linux and only 1 dataset is required for the boot drive
	{
		debug
"mccli group add --dataset=$hd1  --dataset-domain=$vcenter --domain=$domain_temp  --enabled=true --name=$group_name_temp\n";

print_time; print "Creating a group called $group_name_temp which contains dataset $hd1 on $vcenter for Linux VM     ";
log_time; print LOGFILE "Creating a group called $group_name_temp which contains dataset $hd1 on $vcenter for Linux VM     ";
		$status =
$status = `mccli group add --dataset=$hd1 --dataset-domain=$vcenter --domain=$domain_temp  --enabled=true --name=$group_name_temp`;

if ($status =~ /22207/)
	  {
	  	 $message = "New Group Created.  DONE\n";
	  }
	  elsif($status =~ /22233/)
	  {
	  	$message = "Group already exists. FAIL";
	  }
	  elseif ($status =~ /22235/)
	  {
	  	$message = "Group add failed. FAIL";
	  }
	  elseif ($status =~ /23003/)
	  {
	  	$message = "Invalid dataset name specified on the CLI. FAIL";
	  }
	  elsif ($status =~ /23004/)
	  {
	  	$message "Invalid schedule name specified on the CLI. FAIL";
	  }
 elsif ($status =~ /23005/)
	  {
	  	$message "Invalid retention policy name specified on the CLI. FAIL";
	  }
 elsif ($status =~ /23012/)
	  {
	  	$message "Invalid encryption method specified on the CLI. FAIL";
	  }
 elsif ($status =~ /31002/)
	  {
	  	$message "Group add or update failed due to a policy hierarchical management violation. FAIL";
	  }


print "mccli group add dataset status = $status\n";
		debug "\n$status\n";
		print "$message\n";
	}

	#
	debug " \n";
	my $client_domain_temp = $vcenter . '/VirtualMachines';
	my $domain_temp2       = $vcenter . '/VirtualMachines';
	debug
"mccli group add-client --client_domain=$client_domain_temp --client-name=$vm --domain=$domain_temp2 --name=$group_name_temp\n";
	print_time; print "Adding VM client $vm to the group $group_name_temp     ";
	log_time; print LOGFILE "Adding VM client $vm to the group $group_name_temp     ";
	$status =
$status = `mccli group add-client --client-domain=$client_domain_temp --client-name=$vm --domain=$domain_temp2 --name=$group_name_temp`;

if ($status =~ /22243/)
	  {
	  	 $message = "Client group membership successfully updated.  DONE\n";
	  }
	  elsif($status =~ /22234/)
	  {
	  	$message = "Group does not exist. FAIL";
	  }
	  elseif ($status =~ /22236/)
	  {
	  	$message = "Client does not exist. FAIL";
	  }
	  elseif ($status =~ /22242/)
	  {
	  	$message = "Client is already a member of this group. FAIL";
	  }
	  elsif ($status =~ /22269/)
	  {
	  	$message "Unable to add a client to a group. FAIL";
	  }
 elsif ($status =~ /22358/)
	  {
	  	$message "Unable to add a client to group due to incompatibility. FAIL";
	  }


	debug "\n$status\n";
	print "mccli group add client status = $status\n";
print "$message\n";
#
	#
	debug " \n";
	my $proxy_count = num_ele(\@proxies);
	print_time; print "adding $proxy_count proxies to the group\n";
	log_time; print LOGFILE "adding $proxy_count proxies to the group\n";
	
	
	############################ This section added proxies individually ######## and works fine
#	foreach (@proxies) {

# ref line tested $status = `mccli group add-proxy --domain=cahywr1engvca05.itservices.yourcompany.com/VirtualMachines  --name=CAHYWR1ENGVM501-GP --proxy-domain=proxy --proxy-name=hlxtil0537-proxy-1`;
# debug "mccli group add-client --client-domain=cahywr1engvca05.itservices.yourcompany.com/VirtualMachines --client-name=hlxtil0500 --domain=cahywr1engvca05.itservices.yourcompany.com/VirtualMachines --name=hlxtil0500\n";
#		my $domain_temp2 = $vcenter . '/VirtualMachines';
#		my $name_temp2   = $vm . '-GP';
#		debug
#"mccli group add-proxy --domain=$domain_temp2  --name=$name_temp2  --proxy-name=$_\n";
#print_time; print "Adding proxy $_ to group $name_temp2 with Domain: $domain_temp2     ";
#log_time; print LOGFILE "Adding proxy $_ to group $name_temp2 with Domain: $domain_temp2     ";
#		$status =
#`mccli group add-proxy --domain=$domain_temp2  --name=$name_temp2  --proxy-name=$_`;
#		debug "\n$status\n";
#		print "DONE\n";
#	}
#	debug " \n";
	########################## end - adding proxies individually #####################################
	
	my $proxy_list_display = "";
	foreach (@proxies)
	 {
	 	$proxy_list_display = $proxy_list_display . " $_";
	 }
	
	my $proxy_list = "";
	foreach (@proxies)
	 {
	 	$proxy_list = $proxy_list . " --proxy-name=$_";
	 }
	 
		

# ref line tested $status = `mccli group add-proxy --domain=cahywr1engvca05.itservices.yourcompany.com/VirtualMachines  --name=CAHYWR1ENGVM501-GP --proxy-domain=proxy --proxy-name=hlxtil0537-proxy-1`;
# debug "mccli group add-client --client-domain=cahywr1engvca05.itservices.yourcompany.com/VirtualMachines --client-name=hlxtil0500 --domain=cahywr1engvca05.itservices.yourcompany.com/VirtualMachines --name=hlxtil0500\n";
		my $domain_temp2 = $vcenter . '/VirtualMachines';
		my $name_temp2   = $vm . '-GP';
		debug
"mccli group add-proxy --domain=$domain_temp2  --name=$name_temp2  $proxy_list_display\n";
print_time; print "Adding proxy(s) $proxy_list_display to group $name_temp2 with Domain: $domain_temp2     ";
log_time; print LOGFILE "Adding proxy(s) $proxy_list_display to group $name_temp2 with Domain: $domain_temp2     ";
		$status =
$status = `mccli group add-proxy --domain=$domain_temp2  --name=$name_temp2  $proxy_list`;

if ($status =~ /24002/)
	  {
	  	 $message = "Proxy client mappings of a group successfully updated.  DONE\n";
	  }
	  elsif($status =~ /22236/)
	  {
	  	$message = "Client does not exist.";
	  }
	  elseif ($status =~ /22234/)
	  {
	  	$message = "Group does not exist. FAIL";
	  }
	  elseif ($status =~ /24001/)
	  {
	  	$message = "Failed to update proxy client mappings of a group. FAIL";
	  }


print "mccli group add-proxy status = $status";
		debug "\n$status\n";
		print "$message\n";
	
	debug " \n";
	
	######################### end - add proxies all on one command line ################################

	#debug "Add schedule to the group\n";
	debug " \n";
	print_time; print "Adding Schedule to Group $name_temp2    SKIPPED\n";
	log_time; print LOGFILE "Adding Schedule to Group $name_temp2    SKIPPED\n";

#mccli `group edit --dataset=CAHYWR1ENGVM501-HD1  --dataset-domain=cahywr1engvca05.itservices.yourcompany.com --domain=cahywr1engvca05.itservices.yourcompany.com/VirtualMachines --enabled=true --encryption=none --name=CAHYWR1ENGVM501-GP --retention=`;

	my $domain_temp3 = $vcenter . '/VirtualMachines';
	my $name_temp3   = $vm . '-GP';
	debug "mccli group backup --domain=$domain_temp3 --name=$name_temp3\n";
	print_time; print "Creating on-demand backup for Group $name_temp3 on Domain: $domain_temp3     ";
	log_time; print LOGFILE "Creating on-demand backup for Group $name_temp3 on Domain: $domain_temp3     ";
	$status = `mccli group backup --domain=$domain_temp3 --name=$name_temp3`;
	
	if ($status =~ /22226/)
	  {
	  	 $message = "Group disabled.  FAIL\n";
	  }
	  elsif($status =~ /22227/)
	  {
	  	$message = "Group does not contain any clients. FAIL";
	  }
	  elseif ($status =~ /22228/)
	  {
	  	$message = "A client was not backed up because it is disabled, retired or one or more of its
plug-ins has backups disabled. FAIL";
	  }
	  elseif ($status =~ /22234/)
	  {
	  	$message = "Group does not exist. FAIL";
	  }
	  elsif ($status =~ /22301/)
	  {
	  	$message "Scheduled group backups initiated for all clients. DONE";
	  }
 elsif ($status =~ /22311/)
	  {
	  	$message "Scheduled group backups failed to start. FAIL";
	  }
 elsif ($status =~ /23028/)
	  {
	  	$message "Invalid group type. FAIL";
	  }

	
	
	print "mccli group backup status = $status";
	debug "\n$status\n";
	print "DONE\n";

#debug "mccli group backup --domain=cahywr1engvca05.itservices.yourcompany.com/VirtualMachines --name=CAHYWR1ENGVM501-GP\n";
#$status = `mccli group backup --domain=cahywr1engvca05.itservices.yourcompany.com/VirtualMachines --name=CAHYWR1ENGVM501-GP`;

	#
	debug " \n";
	debug "mccli activity show | grep $vm\n";
#	$status = `mccli activity show | grep $vm`;
	debug $status;
}

sub pause
{
	if ($PAUSE == 1)
	{
	debug "Paused. Press ENTER to continue\n";
	<stdin>;
	
	}
}


#######################################################################################
#  Remove VM Image Backup Objects
#
#
#  This subroutine removes the data structures on the Avamar to get a backup ready to go.
#
#  Steps:
#  1) Retire the client
#  2) Get the name of the data source to remove the path to the .vmdk
#  3) delete the Group.
#  5) Delete the dataset if linux or both datasets 1 and 2 if Windows
#  6) Delete the schedule
#  
#
#  Result: The VM will be retired.
#          The objects for the VM will be removed including the Group, Datasets and schedule. 
#  Inputs:
#  a) VM or Client to back up: example: hlxtil0500 (must reside on the vCenter)
#  b) vCenter FQDN!!! example: (just like this) cahywr1engvca05.itservices.yourcompany.com
#  c) "window" as VM type. any other type will be treated as linux. This is for the number of datasets.
#     1 dataset for Linux. Two for windows server.
#  d) @proxies is passed in via MAIN as a global (well not really passed in)
#
#  Output:
#  a) The VM will be retired.
#  b) The Group, Datasets and Schedule will be deleted.
#
#  Calling example: image_backup_vm(\"CAHYWR1ENGVM501", \"cahywr1engvca05.itservices.yourcompany.com", \"windows");
#
#######################################################################################

sub remove_image_backup_vm

{
	my $vm         = ${ $_[0] };
	my $vcenter    = ${ $_[1] };
	my $type_of_vm = ${ $_[2] };
	
#
	debug "\nDebug - type of VM = $type_of_vm\n\n";
	debug " \n";

debug "Retire the Client $vm\n";

my $retire_domain_path = $vcenter . "/VirtualMachines";

debug "mccli client retire --domain=$retire_domain_Path --name=$vm\n";
$status = `mccli client retire --domain=$retire_domain_Path --name=$vm`;

my $group_name_to_delete = $vm . "-GP";

debug "delete the group\n";

debug "mccli group delete --domain=$retire_domain_path --name=$group_name_to_delete\n";
$status =  `mccli group delete --domain=$retire_domain_path --name=$group_name_to_delete`;


debug "delete the first dataset\n";

my $dataset_HD1 = $vm . "-HD1";

debug "mccli dataset delete --domain=$vm --name= dataset_HD1";
$status = "mccli dataset delete --domain=$vm --name= dataset_HD1";

if ( $type_of_vm eq "windows" ) 
    {
	debug "delete the 2nd dataset from this Windows VM\n";
	
	my $dataset_HD2 = $vm . "-HD2";

debug "mccli dataset delete --domain=$vm --name= dataset_HD2";
$status = "mccli dataset delete --domain=$vm --name= dataset_HD2";
    }

	#debug "Add schedule to the group\n";
	debug " \n";
	print_time; print "Adding Schedule to Group $name_temp2    SKIPPED\n";
	log_time; print LOGFILE "Adding Schedule to Group $name_temp2    SKIPPED\n";

}


########################################################################################
# *********** MAIN ************ script Main Entry point
########################################################################################
#
# Execution begins here.
#
# Call init
debug
"-----------------------------------------------------------------------------------------\n\n";

my $login = ( getpwuid $> );
die
"ERROR - not root! This backup vmdk script must run as root. Script halting execution..."
  if $login ne 'root';
  
  
  
  
# $status = (`/usr/bin/which mccli`);
 #if ($status =~ /no which/)
 #  {
   	
 #  	die("ERROR - can't find mccli command. Check if mccli is installed. Check PATH variable to include mccli path, stopped")
#   }


  
  
$PAUSE = 0;
$DEBUG = 0;

#
if ( ($ARGV[0] eq "pause") or ($ARGV[1] eq "pause") )
{
$PAUSE=1;	
}

if ($#ARGV == 0)
{
  if ( ($ARGV[0] eq "pause") or ($ARGV[0] eq "debug") )
  {}
  else
    {
	  print "First argument must be one of pause or debug. Example ./finalvmdk pause or finalvmdk debug\n";
	  die;
    }
}

if ($#ARGV == 1)
{
  if ( (($ARGV[0] eq "pause") or ($ARGV[0] eq "debug")) and (($ARGV[1] eq "pause") or ($ARGV[1] eq "debug")) )
  {}
  else 
    {
	  print "First argument must be one of pause or debug. Example ./finalvmdk pause debug or finalvmdk debug pause\n";
	  print "Second argument must be one of pause or debug. Example ./finalvmdk debug pause or finalvmdk pause debug\n";
	  print "Example: ./finalvmdk [ pause debug ] | [ debug pause ]\n";
	  die;
    }
}

if ($#ARGV > -1)
  {
  print "Backup image .vmdk script has been called with command line arguments of: @ARGV\n\n";
  print LOGFILE "Backup image .vmdk script has been called with command line arguments of: @ARGV\n\n";
   }

if ( ($ARGV[0] eq "debug") or ($ARGV[1] eq "debug") )
{
	$DEBUG = 1;
}

pause;

debug "Step 1) Initializing the Environment...\n";
init_environment;
pause;

debug "Step 2) Getting list of VCenters registered on Avamar $HOSTNAME";

print_time; print "Getting list of Vcenters registered on Avamar Grid $HOSTNAME";
log_time; print LOGFILE "Getting list of Vcenters registered on Avamar Grid $HOSTNAME";

@VCENTERS = get_registered_vcenters;
$num_vcenters = num_ele( \@VCENTERS );
print_time; print "Found $num_vcenters vCenters attached to this Avamar Grid.     DONE\n";
log_time; print LOGFILE "Found $num_vcenters vCenters attached to this Avamar Grid.     DONE\n";

pause;

debug "Step 3) Ping VCenters, Avamar Grids and Proxies to test if connectivity...\n";

print_time; print "Pinging Vcenters, Proxies     ";
log_time; print LOGFILE "Pinging Vcenters, Proxies     ";
print "SKIPPED\n";

# ping_environment;



pause;

debug "Step 3a) This Amamar grid has $num_vcenters vCenter(s) attached to it.\n";

foreach (@VCENTERS)

{
	# If one of the skip variables is 1, then that section of creating dataset, group is skipped.
	# If any of the two skip variables is (0) then a list of proxies is obtained below.
	# To understand this, just look for the "IF" statemennts with the below two variables.
	$skip_windows = 0;
	$skip_linux = 0;
	
	
	$this_vcenter = $_;
	
	print_time; print "Processing VM's on vCenter $this_vcenter attached to Avamar Grid $HOSTNAME";
	log_time; print LOGFILE  "Processing VM's on vCenter $this_vcenter attached to Avamar Grid $HOSTNAME";
	
pause;
	
	debug "Step 4) Processing vCenter $this_vcenter. Getting list of all clients from this vCenter...\n";

    print_time; print "Getting list of VM's hosted on vCenter $this_vcenter\n";
    log_time; print LOGFILE  "Getting list of VM's hosted on vCenter $this_vcenter\n";
	@vcenter_clients = get_clients_from_vcenter( \$this_vcenter );
	

	$num_vcenter_clients = num_ele( \@vcenter_clients );
	
	print_time; print "Found $num_vcenter_clients VM's hosted on vCenter $this_vcenter.     DONE\n";
	log_time;  print LOGFILE "Found $num_vcenter_clients VM's hosted on vCenter $this_vcenter.     DONE\n";
	debug "Vcenter Clients = @vcenter_clients";

	#debug "$this_vcenter";

	debug "        Found $num_vcenter_clients client(s) from vCenter: $this_vcenter\n";

	#foreach (@vcenter_clients)
	#  {
	#   debug "Vcenter_client = $_\n";
	#  }

pause;


	debug "Step 5) Filtering Windows clients on keywords @LINUX_PARTIAL_NAMES...\n";
	@windows_clients = "";
	foreach (@WINDOWS_PARTIAL_NAMES)
	  {
	  print_time; print "Finding Windows VM's matching the partial name of: $_.\n";
	  log_time; print LOGFILE "Finding Windows VM's matching the partial name of: $_.\n";
	  @more_windows_clients = name_filter( \$_, \@vcenter_clients );
	  $num_windows_clients = num_ele(\@more_windows_clients);
	  print_time; print "Found $num_windows_clients New Windows Clients to backup.     DONE\n";
	  log_time; print LOGFILE "Found $num_windows_clients New Windows Clients to backup.     DONE\n";
	  push @windows_clients, @more_windows_clients;
	  }
	
		debug "    Found $num_windows_clients windows clients from $num_vcenter_clients client(s)\n";

pause;
	debug "Step 6) Filtering Linux clients on keywords @WINDOWS_PARTIAL_NAMES...\n";
	@linux_clients = "";
	foreach (@LINUX_PARTIAL_NAMES)
	  {
	  print_time; print "Finding Linux VM's matching the partial name of: $_.\n";
	  log_time; print LOGFILE "Finding Linux VM's matching the partial name of: $_.\n";
	  @more_linux_clients = name_filter( \$_, \@vcenter_clients );
	  $num_linux_clients = num_ele(\@more_linux_clients);
	  print_time; print "Found $num_linux_clients New Linux Clients to backup.     DONE\n";
	  log_time; print LOGFILE "Found $num_linux_clients New Linux Clients to backup.     DONE\n";
	  push @linux_clients, @more_linux_clients;
	  }

		debug "    Found $num_linux_clients linux clients from $num_vcenter_clients client(s)\n";

pause;
	debug "Step 7) Getting list of ALL clients already protected with a .vmdk backup...\n";

# reference: @protected_clients = get_backup_clients_from_domain("/cahywr1engvca05.itservices.yourcompany.com/VirtualMachines");

	$vcenter_path = "/" . $this_vcenter . "/VirtualMachines";
	
	print_time; print "Getting list of already protected VM's from $vcenter_path\n";
	log_time; print LOGFILE "Getting list of already protected VM's from $vcenter_path\n";

	@protected_clients = get_backup_clients_from_domain("/$vcenter_path");

	debug "\n\nCurrent Protected Clients found are:\n\n";

	foreach (@protected_clients) {
		debug "$_\n";
	}
	
	$num_protected_clients = num_ele(\@protected_clients);
	
	print_time; print "Found $num_protected_clients already protected clients from the domain $vcenter_path\n";
	log_time; print LOGFILE "Found $num_protected_clients already protected clients from the domain $vcenter_path\n";
	
################################################################################################################
# Identify Windows Clients needing protection
################################################################################################################
	

	# Protecting Windows Clients
	@new_windows_clients_needing_protection = '';
	pause;
	debug "Step 8) Searching for New Windows Client(s) to be protected\n";
	@new_windows_clients_needing_protection = array_minus( @windows_clients, @protected_clients );

	if ( @new_windows_clients_needing_protection != '' ) {
		debug("Setting up protection for this list of new windows clients:\n");
		foreach (@new_windows_clients_needing_protection) {
			debug "   $_\n";
			print_time; print "New Windows VM $_ from vCenter $this_vcenter will be protected\n";
			log_time; print LOGFILE "New Windows VM $_ from vCenter $this_vcenter will be protected\n";
		}
	}
	else {
		debug "   none found!\n";
		print_time; print "No Windows VM's are found to be new from last image backup run against vCenter $this_vcenter\n";
		log_time; print LOGFILE "No Windows VM's are found to be new from last image backup run against vCenter $this_vcenter\n";
	}
	
	
	
################################################################################################################
# Identify Windows Clients removed from vCenter and still existing on Avamar
################################################################################################################
	

	# Remove Windows Clients from Avamar
	@windows_clients_needing_retirement = '';
	pause;
	debug "Step 8a) Searching for New Windows Client(s) to be removed\n";
	@windows_clients_needing_retirement = array_minus( @protected_clients, @windows_clients );

	if ( @windows_clients_needing_retirement != '' ) {
		debug("Setting up retirement for this list of windows clients:\n");
		foreach (@windows_clients_needing_retirement) {
			debug "   $_\n";
			print_time; print "Windows VM $_ from vCenter $this_vcenter will be retired\n";
			log_time; print LOGFILE "Windows VM $_ from vCenter $this_vcenter will be retired\n";
		}
	}
	else {
		debug "   none found!\n";
		print_time; print "No Windows VM's are found to be registered on Avamar and do not exist on vCenter $this_vcenter\n";
		log_time; print LOGFILE "No Windows VM's are found to be registered on Avamar and do not exist on vCenter $this_vcenter\n";
	}
	

################################################################################################################
# Identify Linux Clients removed from vCenter and still existing on Avamar
################################################################################################################
	

	# Remove Linux Clients from Avamar
	@linux_clients_needing_retirement = '';
	pause;
	debug "Step 8b) Searching for New Linux Client(s) to be removed\n";
	@linux_clients_needing_retirement = array_minus( @protected_clients, @linux_clients );

	if ( @linux_clients_needing_retirement != '' ) {
		debug("Setting up retirement for this list of linux clients:\n");
		foreach (@linux_clients_needing_retirement) {
			debug "   $_\n";
			print_time; print "Linux VM $_ from vCenter $this_vcenter will be retired\n";
			log_time; print LOGFILE "Linux VM $_ from vCenter $this_vcenter will be retired\n";
		}
	}
	else {
		debug "   none found!\n";
		print_time; print "No Linux VM's are found to be registered on Avamar and do not exist on vCenter $this_vcenter\n";
		log_time; print LOGFILE "No Linux VM's are found to be registered on Avamar and do not exist on vCenter $this_vcenter\n";
	}
	

################################################################################################################
# Identify Linux Clients needing protection
################################################################################################################
	

	# Protecting LINUX Clients
	@new_linux_clients_needing_protection = '';
	pause;
	debug "Step 9) Searching for New Linux Client(s) to be protected\n";
	@new_linux_clients_needing_protection =
	  array_minus( @linux_clients, @protected_clients );

	if ( @new_linux_clients_needing_protection != '' ) {
		debug("Setting up protection for this list of new linux clients:\n");
		foreach (@new_linux_clients_needing_protection) {
			debug "   $_\n";
			print_time; print "New Linux VM $_ from vCenter $this_vcenter will be protected\n";
			log_time; print LOGFILE "New Linux VM $_ from vCenter $this_vcenter will be protected\n";
		}
	}
	else {
		debug "   none found!\n";
		print_time; print "No Linux VM's are found to be new from last image backup run against vCenter $this_vcenter\n";
		log_time; print LOGFILE "No Linux VM's are found to be new from last image backup run against vCenter $this_vcenter\n";
	}

################################################################################################################
# Register new VM's which are found
################################################################################################################


pause;
	debug
"Step 10) Registering any new if found Windows Clients for Image Backup on this Avamar Grid";

	if ( @new_windows_clients_needing_protection != '' ) {
		debug
"   Now registering additional windows clients for protection with Avamar...\n\n";
		register_clients_for_image_backup(
			\@new_windows_clients_needing_protection,
			\$this_vcenter );
	}
	else {
		debug("   \nThere are no additional new Windows clients found needing protection at this time on $this_vcenter vCenter\n");
		print_time; print "There are no additional new Windows clients found needing protection at this time on $this_vcenter vCenter\n";
		log_time; print LOGFILE "There are no additional new Windows clients found needing protection at this time on $this_vcenter vCenter\n";
		$skip_windows = 1;
	}

pause;	
	debug
"Step 11) Registering any new if found Linux Clients for Image Backup on this Avamar Grid";

	if ( @new_linux_clients_needing_protection != '' ) {
		debug
"   Now registering additional Linux clients for protection with Avamar...\n\n";

		register_clients_for_image_backup(
			\@new_linux_clients_needing_protection,
			\$this_vcenter );
	}
	else {
		debug("   \nThere are no additional new Linux clients found needing protection at this time on $this_vcenter vCenter\n");
        $skip_linux = 1;	
	}

    if (($skip_linux == 0) || ($skip_windows == 0))
       {
       pause;
       
       ################################################################################################################
       # Get list of proxies
       ################################################################################################################
       
	   debug "Step 12) Get the list of proxies on this Avamar Grid\n";
	   print_time; print "Getting list of proxies on Avaamr Grid $HOSTNAME";
	   log_time; print LOGFILE "Getting list of proxies on Avaamr Grid $HOSTNAME";
	   @proxies = get_proxies;
	   $num_proxies = num_ele(\@proxies);
	   print_time; print "Found $num_proxies proxies on Avamar Grid $HOSTNAME";
	   log_time; print LOGFILE "Found $num_proxies proxies on Avamar Grid $HOSTNAME";
       }

   if ($skip_windows == 0)
    {
     pause;
     debug "Step 13) Create datasets, groups and add proxies to groups for windows hosts";

	foreach (@new_windows_clients_needing_protection) {
		print_time; print "Starting to build Windows image backup objects for VM $_\n";
		log_time; print LOGFILE "Starting to build Windows image backup objects for VM $_\n";
		image_backup_vm( \"$_", \"$this_vcenter", \"windows" );
		print_time; print "Finished building Windows image backup objects for VM $_\n";
		log_time; print LOGFILE "Finished building Windows image backup objects for VM $_\n";
	    }
   }
	if ($skip_linux == 0)
	{
pause;
 debug "Step 14) Create datasets, groups and add proxies to groups for linux hosts";

	foreach (@new_linux_clients_needing_protection) {
		print_time; print "Starting to build Linux image backup objects for VM $_\n";
		log_time; print LOGFILE "Starting to build Linux image backup objects for VM $_\n";
		image_backup_vm( \"$_", \"$this_vcenter", \"linux" );
		print_time; print "Finished building Linux image backup objects for VM $_\n";
		log_time; print LOGFILE "Finished building Linux image backup objects for VM $_\n";
	    }
	}

}    # End of the foreach looping thru vCenters

print_time; print "The Image Backup script has finished processing image backups and will now exit\n";
log_time; print LOGFILE "The Image Backup script has finished processing image backups and will now exit\n";

$status = close LOGFILE;

# End of main

# put in VCenter check
#  mccli server show-services

