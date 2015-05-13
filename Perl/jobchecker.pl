#!c:\perl\bin\perl.exe
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# 
# Name: 		jobchecker.pl
#
# Author:		Patrick Costello
#                       
#
# Description:	Runs jobchecker process for EWOC job queue
#               
#               
# Change History:
# ---------------
#
# 11-Apr-2007	Patrick Costello	Ver 1.0		Creation
# 30-Apr-2007	Pat Costello		Ver 1.1		Added lock file and time stamp
#												in seconds              
#
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# *****************************************************	#
#							#
# Header & Include Section				#
#							#
# ***************************************************** #

# Include Standard Customised Perl Modules that are required for this script
use PFIZER_env;
use PFIZER_ora;
use PFIZER_mail;
use PFIZER_misc;

# Include other modules used by this program (these are standard perl modules
# located in $PERL_HOME\lib\file or \lib)
#
use File::Copy;

# ***************************************************** #
# 							#
# Parameter Declaration Section				#
#							#
# ***************************************************** #

# Initialise EWOC  environment
PFIZER_env.init ("H:\\EWOC\\etc\\EWOC.env");

# timestamp file extensions
# my($ext) = PFIZER_misc::time_ext();
my($ext) = PFIZER_misc::ewoc_datestamp();

# etc directory
my($etcdir)  = $ENV{"APP_HOME"} . $ENV{"DIR_SEP"} .
               $ENV{"ETC_DIR"} . $ENV{"DIR_SEP"};

# log directory
my($logdir)  = $ENV{"APP_HOME"} . $ENV{"DIR_SEP"} .
               $ENV{"LOG_DIR"} . $ENV{"DIR_SEP"};

# temporary directory
my($tmpdir)  = $ENV{"APP_HOME"} . $ENV{"DIR_SEP"} .
               $ENV{"TMP_DIR"} . $ENV{"DIR_SEP"};

# data directory
my($datadir)  = $ENV{"APP_HOME"} . $ENV{"DIR_SEP"} .
               $ENV{"DATA_DIR"} . $ENV{"DIR_SEP"};

# archive directory
my($archdir) = $datadir . $ENV{"ARCH_DIR"} . $ENV{"DIR_SEP"};

# log file name
my($logfile) = $logdir . "jobchecker-" . "_" . $ext . ".log";

# error file name
my($errfile) = $logdir . "jobchecker-" . "_" . $ext . ".err";

# lock file name
my($lockfile) = $tmpdir . "jobchecker" . ".lock";

# today
my($today) = PFIZER_misc::time_ext();

# yesterday
my($yesterday) = PFIZER_misc::time_ext() - 1;

# temporary file
my($tmp_file) = $tmpdir . "tmp.log";

# db connect string to target EWOC database
my($dbconn) = $ENV{"DB_USER"};


# ************************************* #
#					#
# Sub Functions Declarations		#
#					#
# ************************************* #


# ++++++++++++++++++++++++++++++++++++++++++++
# Usage: check_error ("error_type" "log file")
# where error_type is - ORA-, ERR-
#
# Typically this function is called after "sqlplus"
# ++++++++++++++++++++++++++++++++++++++++++++

sub check_errors
{

  # Copy parameters into local variables
  my($error_type) = $_[0] . "-"  ;
  my($log_file) = $_[1] ;

  $errors_found = 0;

  # Return code
  my($rc) = 0;

  ###################################
  # Check for various Oracle errors #
  ###################################

  # Get contents of log file
  if (!open(LOGFILE, $log_file)) {
    print STDERR "Cannot open log file $log_file\n";
  }

  # Read each line of file
  while (<LOGFILE>) {
    # If match to the error_type passed in, set flag
    if (/$error_type/) {
      # Set the flag
      $errors_found = 1;
      # Break out of the loop (no point in checking the rest if we have
      # already found an error)
      last;
    }
  }
  # Close file
  close LOGFILE;

  # Check if error flag defined

  if ( $errors_found == "1") {
	$warning = 1;
    	$rc = 1; # errors found
  }
  else { # no errors
    	$rc = 0;
  }

  return $rc;

} # end of sub check_errors ();


# ************************************************	#
#							#
# Main Program Body					#
#							#
# ************************************************	#

# Redirect STDOUT and STDERR to files named
PFIZER_misc::redirect_outputs($logfile, $errfile);

print "********************************************************************\n";
print "\n";
print "Jobchecker process started " . PFIZER_misc::time_stamp() ."\n";
print "\n";
print "********************************************************************\n";

#############################################################
# Run Lock Script Check
#
#############################################################

print "\n";
print "Checking for Lock Script (jobchecker running or in failed state?)...\n";

# Need to determine if jobchecker is already running, if so exit
if (-e $lockfile) {
	# Notify and exit directly - don't want a mail sent for this
	print "Jobchecker is already running or is in failed state - exiting...\n";
	exit;
}
else {
		# Otherwise create the lock file
		print "Jobchecker is not currently running - continuing...\n";
		open (LOCK,">$lockfile") || die ("Cannot open lock file!\n");
		close (LOCK);
}

#############################################################
# Run EWOC Job Queue Check Script
#
#############################################################

print "\n";
print "Calling EWOC Job Queue Check Script...";

%rc = PFIZER_ora::sqlplus ("check_queue.sql");
# Terminate for FATAL SQL*Plus error
if ($rc{"RETURN_CODE"} eq "FATAL" || $rc{"RETURN_CODE"} eq "WARNING") {
	print "Failed\n";
	print ">> Aborting\n";
	PFIZER_misc::tidy_exit("FATAL", $logfile);
}
print "Done\n";

# Check for any "ORA-" errors in the SQL log file
print ">> Checking for Errors...";
if ( check_errors ("ORA-", $rc{OUT_FILE}) eq "0") {
	print "None Found\n";
}
else {
	$warning = 1;
	print "Errors Found\n";
	print ">> Aborting $ENV{APP_NAME} - Job: $ENV{JOB_NAME}\n";
	PFIZER_misc::tidy_exit("FATAL", $logfile);
}

#############################################################
# Execute commands from job queue table
#
#############################################################

print ">> Processing Job Command file\n";
# Process the commands returned from job queue
if (!open(SQLOUTFILE, $rc{OUT_FILE})) {
    print STDERR "Cannot open log file $rc{OUT_FILE}\n";
}
else {
   # Read each line of file
   $counter = 0;
   while (<SQLOUTFILE>) {
      print "********************************************************************\n";
      print "Executing command " . $_;

	  # Run the command
	  $rc = system($_);
      $counter = $counter + 1;
  if ($rc)
  {
    # If System command has errored abort process and mail out
    $rc = $rc/256;
    print "System command returned a non-zero code $rc\n";
	print "Investigate the command for errors\n";
	PFIZER_misc::tidy_exit("FATAL", $logfile);
   }
}
# Close file
close SQLOUTFILE;
}

  if ( $counter == "0") {
    print "***Job command file has no new entries to process***\n";
  }

print "********************************************************************\n";
print "*                Command execution section completed               *\n";
print "********************************************************************\n";

#############################################################
# Update the job queue table entries once complete
#
#############################################################

if ( $counter > "0") {
print "\n";
print "Calling EWOC Job Queue Update Script...";

%rc = PFIZER_ora::sqlplus ("update_queue.sql");
# Terminate for FATAL SQL*Plus error
if ($rc{"RETURN_CODE"} eq "FATAL" || $rc{"RETURN_CODE"} eq "WARNING") {
	print "Failed\n";
	print ">> Aborting\n";
	PFIZER_misc::tidy_exit("FATAL", $logfile);
}
print "Done\n";

# Check for any "ORA-" errors in the SQL log file
print ">> Checking for Errors...";
if ( check_errors ("ORA-", $rc{OUT_FILE}) eq "0") {
	print "None Found\n";
}
else {
	$warning = 1;
	print "Errors Found\n";
	print ">> Aborting $ENV{APP_NAME} - Job: $ENV{JOB_NAME}\n";
	PFIZER_misc::tidy_exit("FATAL", $logfile);
}

print "\n";
print "Update job queue activity complete";

}
  
#############################################################
# Tidy up and exit
#
#############################################################

print "\n";
print "Entering Tidy up and Exit Section " . PFIZER_misc::time_stamp() ."\n";

print ">> Removing logfiles older than 14 days...";
PFIZER_misc::purge_dir ($logdir, 14);
print "Done\n";

print ">> Removing all other temporary files created older than 2 days...";
PFIZER_misc::purge_dir ($tmpdir, 2);
print "Done\n";

print ">> Removing all archived export DMP files older than 14 days...";
PFIZER_misc::purge_dir ($archdir, 14);
print "Done\n";

# Remove the lock file
print "Removing lock file\n";
unlink($lockfile);

# Log to Event Log and exit
if (defined($warning)) {
	print "********************************************************************\n";
	print "\n";
	print "Finished with !! Warnings !! " . PFIZER_misc::time_stamp() ."\n";
	print "\n";
	print "********************************************************************\n";
	PFIZER_misc::tidy_exit("WARNING", $logfile);
}
else {
	print "********************************************************************\n";
	print "\n";
	print "Finished " . PFIZER_misc::time_stamp() ."\n";
	print "\n";
	print "********************************************************************\n";
	if ( $counter > "0") {
	# Only send a mail if new jobs in queue have been processed
	# as jobchecker runs frequently
	PFIZER_misc::tidy_exit("SUCCESS", $logfile);
	}
	#exit $ENV{error_number};
}
