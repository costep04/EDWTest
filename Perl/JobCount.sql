var x VARCHAR2(10);
set pages 0 feedback off echo off verify off;
BEGIN
SELECT count(*)
INTO :x
FROM   job_queue
WHERE  jqstat_id = 1
AND    jqtyp_id  = 5;
END;
/
print :x;
exit;