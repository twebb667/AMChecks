WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

SET LINES 132 
SET PAGES 1000
SET HEADING off

--
-- Simple RMAN check script by Tony. 21/08/14
-- Added a bit more complexity 27/01/15 (Tony)
-- Added in processing for 'COMPLETE WITH WARNINGS' and changed the initial select to cope with
--
SET FEEDBACK off
SET LINES 200
SET SERVEROUTPUT on
SET TAB off

DECLARE
    v_age                    PLS_INTEGER;
    v_count                  PLS_INTEGER;
    v_database               v$database.name%TYPE:=SYS_CONTEXT('USERENV','DB_NAME');
    v_duration               VARCHAR2(8):=NULL;
    v_environment            VARCHAR2(8):=NULL;
    v_log_mode               v$database.log_mode%TYPE;
    v_output                 VARCHAR2(2000):=NULL;
    v_rman_summary           VARCHAR2(2000):=NULL;
    v_start_time             v$rman_backup_job_details.start_time%TYPE;
    v_success_start_time     v$rman_backup_job_details.start_time%TYPE;
    v_status                 VARCHAR2(2000):=NULL;
BEGIN

    -- Maybe derive the next 2 from server name, instance name or another table?

    IF (v_environment IS NOT NULL)
    THEN
        v_environment := ' (' || v_environment || ') ';
    END IF;

    v_age := 1;
    v_duration := '1 day';

    -- Two error conditions are checked:
    --
    --  1) No recent backup
    --  2) Last ARCHIVELOG or DB backup failed
    --
    SELECT /*+ rule */ COUNT(*)
    INTO  v_count
    FROM  V$RMAN_BACKUP_JOB_DETAILS 
    WHERE start_time > TRUNC(sysdate)-v_age
    AND   status IN ('COMPLETED', 'COMPLETED WITH WARNINGS')
    AND   (input_type LIKE 'DB%') OR (input_type = 'ARCHIVELOG');

    SELECT log_mode 
    INTO   v_log_mode
    FROM   v$database;

    IF (v_log_mode = 'NOARCHIVELOG')
    THEN
        DBMS_OUTPUT.PUT_LINE('** Database is in NOARCHIVELOG Mode. No RMAN checks will be run for ' || v_database || ' **');
    ELSIF (v_count < 1)
    THEN
        DBMS_OUTPUT.PUT_LINE('** ERROR: No RMAN backups for ' || v_database || v_environment || ' in the last ' || v_duration || ' (at least) **');
    ELSE
        SELECT /*+ rule */ rman_summary, status
        INTO v_rman_summary, v_status
        FROM (
        SELECT  /*+ rule */ TO_CHAR(start_time, 'Day')
         || ' ' || TO_CHAR(start_time, 'dd Mon yyyy (hh24:mi:ss)') || ' => '
         || TO_CHAR(end_time, '(hh24:mi:ss)') || ' - ('
         || input_type || ': Backup ' || status || ')' AS rman_summary, rownum, status, start_time
        FROM V$RMAN_BACKUP_JOB_DETAILS
        WHERE ((input_type like 'DB %') OR (input_type = 'ARCHIVELOG'))
        AND start_time > TRUNC(sysdate)-v_age
	AND status <> 'RUNNING'
        ORDER BY end_time DESC)
        WHERE rownum=1;

        IF (v_status IN ('COMPLETED', 'COMPLETED WITH WARNINGS'))
        THEN
            DBMS_OUTPUT.PUT_LINE('** No RMAN alerts for ' || v_database || v_environment || ' in the last ' || v_duration || ' **');
        ELSE
            DBMS_OUTPUT.PUT_LINE('** ERROR ' || v_rman_summary || ' on ' || v_database || v_environment || ' in the last ' || v_duration || ' **');
        END IF;
    
        BEGIN
            SELECT /*+ rule */ GREATEST(start_time) 
            INTO  v_success_start_time
            FROM  (SELECT /*+ rule */ start_time 
                   FROM V$RMAN_BACKUP_JOB_DETAILS 
                   WHERE status IN ('COMPLETED', 'COMPLETED WITH WARNINGS')
                   AND   input_type like 'DB%'
                   ORDER BY start_time DESC)
            WHERE ROWNUM = 1;
        
            DBMS_OUTPUT.PUT_LINE('** Last Successful Database Backup for ' || v_database || v_environment || ' was on ' || TO_CHAR(v_success_start_time,'fmDay') || ' ' || TO_CHAR(v_success_start_time,'DD Mon YYYY (HH12:MI:SS am)') || ' **');

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('** No Recent Successful Database Backups Found for ' || v_database || v_environment || ' **');
        END;

        BEGIN
            SELECT /*+ rule */ status, start_time
            INTO  v_status, v_start_time
            FROM  (SELECT /*+ rule */ start_time , status
                   FROM V$RMAN_BACKUP_JOB_DETAILS 
                   WHERE input_type like 'DB%'
                   ORDER BY start_time DESC)
            WHERE ROWNUM = 1;
    
            DBMS_OUTPUT.PUT_LINE('** Last Database Backup for ' || v_database || v_environment || ' had a status of ' || v_status || ' and ran on ' || TO_CHAR(v_start_time,'fmDay') || ' ' || TO_CHAR(v_start_time,'DD Mon YYYY (HH12:MI:SS am)') || ' **');

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('** No Recent Database Backups Found for ' || v_database || v_environment || ' **');
        END;

    END IF; 
END;
/
