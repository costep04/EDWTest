SET feedback off 
SET heading off 
SET linesize 50 
SET echo off 
SET termout off


SELECT 'CALL '||trim(command)
FROM   job_queue
WHERE  jqstat_id = 1
AND    jqtyp_id  = 5


SPOOL runthis.bat
/

--SELECT 'sqlplusw ewoc/password@ccmstg @JobChecker_Close.sql'
--FROM   dual;

SPOOL off

exit