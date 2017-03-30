
--
-- Lovingly crafted by Tony Webb 19th August 2014
-- Amended by Tony Webb 26th January 2015 to add in a mimimum switch check.
-- Minor changes in text output Tony Webb May 2015
--

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

SET HEADING OFF
SET FEEDBACK OFF
SET LINES 200
SET SERVEROUTPUT ON
SET TAB OFF

DECLARE
  v_archive_log_target v$parameter.value%TYPE:=86400;
  v_count              PLS_INTEGER:=0;
  v_database           v$database.name%TYPE:=SYS_CONTEXT('USERENV','DB_NAME');
  v_gap_seconds        PLS_INTEGER:=0;
  v_status             VARCHAR2(200):='** No unusual redo log switching for ' || v_database || ' **';
  v_target_type        VARCHAR2(20):='1 DAY';

BEGIN

  SELECT COUNT(*) 
  INTO   v_count 
  FROM (SELECT thread#, count(*) AS hourly_log_switches,
               TO_CHAR(first_time,'DD-MM-YY HH24')
        FROM  v$log_history
        GROUP BY thread#,TO_CHAR(first_time,'DD-MM-YY HH24'))
  WHERE hourly_log_switches > 60;

  IF (v_count > 0)
  THEN
    v_status:='** WARNING on ' || v_database || ':- More than 60 log switches in one hour. **';
  ELSE
        
  -- Also need to check for too few log switches (if ARCHIVE_LAG_TARGET is set we aim for a minimum of 1 switch a day)

      SELECT NVL(MAX(value),0)  
      INTO v_archive_log_target
      FROM v$parameter 
      WHERE name = 'archive_log_target'; 

      IF (v_archive_log_target = 0)
      THEN
        v_archive_log_target:=86400;
        v_target_type:='ARCHIVE_LOG_TARGET';
      END IF;
 
      SELECT ROUND(MAX(last_log_time), 2) 
      INTO   v_gap_seconds
      FROM   (SELECT thread#,
                     first_time,
                     LAG(first_time)               OVER (ORDER BY thread#, sequence#) AS last_first_time,
                     (first_time - LAG(first_time) OVER (ORDER BY thread#, sequence#)) * (24 * 60 * 60) AS last_log_time,
                     LAG(thread#)                  OVER (ORDER BY thread#, sequence#) AS last_thread#
              FROM v$log_history)
      WHERE  last_first_time IS NOT NULL
      AND    last_thread# = thread#
      AND    first_time > SYSDATE - 1;

      IF (v_gap_seconds > v_archive_log_target)
      THEN
        v_status:='** ERROR on ' || v_database || ':- Log switch gap of ' || TO_CHAR(v_gap_seconds) || ' seconds is more than the target (' || v_target_type || ') of ' || TO_CHAR(v_archive_log_target) || ' seconds **';
      END IF;

  END IF;

  DBMS_OUTPUT.PUT_LINE(v_status);

END;
/
