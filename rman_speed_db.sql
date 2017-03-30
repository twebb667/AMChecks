-- 
-- Should be run on the local database (not the rman catalog).
-- 
SET LINES 120
SET PAGES 1000
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING ON

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

Prompt 
Prompt RMAN Backup speeds (datafiles)
Prompt ===============================

COL started     FORMAT A24 HEADING "Started"     JUSTIFY CENTRE
COL time_taken  FORMAT A26 HEADING "Time Taken"  JUSTIFY CENTER
COL speed       FORMAT A16 HEADING "Speed"       JUSTIFY CENTER
COL db_name     FORMAT A8  HEADING "Database"    JUSTIFY CENTER
COL ended       FORMAT A20 HEADING "Ended"       JUSTIFY CENTER
COL compression FORMAT A12 HEADING "Compression" JUSTIFY CENTER

SELECT TO_CHAR(start_time, 'Dy') || ' ' || TO_CHAR(start_time, 'dd/mm/yy (hh24:mi:ss)')  AS started,
       TO_CHAR(end_time, 'dd/mm/yy (hh24:mi:ss)') AS ended,
       LPAD(DECODE(FLOOR((end_time-start_time)*24)|| ' Hours ', '0 Hours ', '       ', '1 Hours ', '1 Hour ', FLOOR((end_time-start_time)*24)|| ' Hours '),10) ||
             LPAD(MOD(FLOOR((end_time-start_time)*24*60),60) || ' Mins ',8) ||
             LPAD(MOD(FLOOR((end_time-start_time)*24*60*60),60) || ' Secs ',8) AS time_taken,
       RTRIM(RPAD(TO_CHAR((input_bytes / (end_time - start_time)/(24*60*60*1024*1024)),'9,990.90'),8) || ' MB/sec') AS speed,
       TO_CHAR(compression_ratio,'999,999.99') as compression
FROM   v$RMAN_BACKUP_JOB_DETAILS
WHERE  input_type like 'DB %'
AND    start_time > sysdate -32
AND    status <> 'FAILED'
ORDER BY start_time DESC;

prompt

