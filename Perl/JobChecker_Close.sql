SPOOL JobChecker_Close.txt

UPDATE job_queue
SET    jqstat_id = 2
WHERE  jqstat_id = 1
AND    jqtyp_id  = 5;

COMMIT;

SPOOL off

EXIT;
