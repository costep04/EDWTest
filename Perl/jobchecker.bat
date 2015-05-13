REM ********************************************************************
REM * Name : jobchecker.bat                                            *
REM ********************************************************************
REM * Purpose:  Takes commands from EWOC job queue table and runs them *
REM *     	in turn.  A lock is placed while jobs are running      *
REM ********************************************************************
REM * History:							       *
REM *								       *						
REM * Status	BY	Date		Comments		       *	
REM * ******    *****   ********    	********		       *
REM * Created	PC	02/05/07	Initial version		       *
REM *								       *	
REM ********************************************************************

@echo off
REM Set environment variables
REM =========================
set dbuser=ewoc
set dbpass=password
set targetfile=runthis.bat
set lockfile=jobchecker.lock
set dbase=ccmstg
set current=Checking for new job queue entries
set retcode=0

REM Get timestamp information
======================================================
date <nul >~datetime.txt
for /f "eol=E tokens=5-9 delims=/ " %%j in (~datetime.txt) do (
  set day=%%j
  set month=%%k
  set year=%%l
)

time <nul >~datetime.txt
for /f "eol=E tokens=5-9 delims=.: " %%i in (~datetime.txt) do (
 set hour=%%i
 set minute=%%j
 set second=%%k
 set hundredth=%%l
)
if %hour% LSS 10 set hour=0%hour%

del ~datetime.txt

set today=%day%%month%%year%
set tod=%hour%%minute%%second%
set timestamp=%today%%tod%
set logfile=jobchecker%today%%tod%.log

echo ================================================== > %logfile% 
echo Starting JobChecker on %DATE% at %TIME% >> %logfile%
echo Jobchecker is running on %COMPUTERNAME% >> %logfile%

echo ================================================== >> %logfile%
echo Checking for lockfile >> %logfile%

if exist %lockfile% goto lockerror

echo No lock file found, creating ... >> %logfile%

REM Jobchecker is starting, so create lock file and remove
REM any existing command targetfile

echo Locked > %lockfile%
if exist %targetfile% del %targetfile%

echo ================================================== >> %logfile%
echo %current% at %TIME% >> %logfile%
echo ================================================== >> %logfile%
REM Check if there are new entries in CCM EWOC job queue

REM Have to use -s option here or returned result is not correct
for /f %%D in ('sqlplus -s %dbuser%/%dbpass%@%dbase% @JobCount.sql') do (set res=%%D)

echo Number of new jobs detected = %res% >> %logfile%

if %res%==0 goto nojobs

REM echo %ERRORLEVEL%

if errorlevel 1 goto error

echo %current% has completed >> %logfile%
echo. >> %logfile%
echo. >> %logfile%

set current=Retrieving new job commands
echo ================================================== >> %logfile%
echo %current% at %TIME% >> %logfile%
echo ================================================== >> %logfile%
REM Select new job commands into runthis.bat from CCM EWOC job queue
sqlplus -L %dbuser%/%dbpass%@%dbase% @JobChecker.sql

REM echo %ERRORLEVEL%

if errorlevel 1 goto error
echo %current% has completed >> %logfile%
echo. >> %logfile%
echo. >> %logfile%

set current=Running retrieved commands
echo ================================================== >> %logfile%
echo %current% at %TIME% >> %logfile%
echo ================================================== >> %logfile%
REM Use call as this returns control to current script
call %targetfile% >> %logfile%

REM echo %ERRORLEVEL%

if errorlevel 1 goto error
echo. >> %logfile%
echo %current% has completed >> %logfile%
echo. >> %logfile%
echo. >> %logfile%

set current=Updating job queue table
echo ================================================== >> %logfile%
echo %current% at %TIME% >> %logfile%
echo ================================================== >> %logfile%
sqlplus -L %dbuser%/%dbpass%@%dbase% @JobChecker_Close.sql

REM echo %ERRORLEVEL%

if errorlevel 1 goto error
echo. >> %logfile%
echo %current% has completed >> %logfile%
echo. >> %logfile%
echo. >> %logfile%
goto end

:nojobs
echo No new jobs have been found in the queue. Exiting.... >> %logfile%
goto end

:error
echo Errors Detected in %current% activity >> %logfile%
echo - please fix and re-run >> %logfile%
set retcode=1
goto end

:lockerror
echo Jobchecker is already running or in failed state (lock file exists) >> %logfile% 
echo - please check and re-run >> %logfile%
set retcode=1

:end
echo ================================================== >> %logfile%
echo Finished JobChecker on %DATE% at %TIME% >> %logfile%
echo ================================================== >> %logfile%
if %retcode%==0 del %lockfile%
exit retcode
