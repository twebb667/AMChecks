WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

--
-- Simple RMAN check script by Tony. 21/08/14
-- Added a bit more complexity 27/01/15 (Tony)
-- Added in processing for 'COMPLETE WITH WARNINGS'
-- Added in parameters of num_days (mandatory) and detail_type ('B' brief, 'V' verbose). Tony 03/12/15
-- Added latest backup details Tony Webb 03 Feb 2016
-- Qualified check comment Tony Webb 22 Apr 2016

SET FEEDBACK OFF
SET HEADING OFF
SET LINES 200
SET PAGES 0
SET SERVEROUTPUT on
SET TAB OFF
SET TRIMSPOOL ON 
SET VERIFY OFF

SET TERMOUT OFF
COLUMN 1 NEW_VALUE 1
COLUMN 2 NEW_VALUE 2
SELECT '' "1", '' "2" FROM DUAL WHERE ROWNUM = 0;
DEF DAYS='&1'
DEF OUTPUT_TYPE='&2'
SET TERMOUT ON

DECLARE
    v_count                  PLS_INTEGER;
    v_database               v$database.name%TYPE:=SYS_CONTEXT('USERENV','DB_NAME');
    v_days                   NUMBER:=1;
    v_daystring              VARCHAR2(4):='days';
    v_detail                 VARCHAR2(2000):='B';
    v_environment            VARCHAR2(8):=NULL;
    v_last_backup            v$rman_backup_job_details.start_time%TYPE;
    v_log_mode               v$database.log_mode%TYPE;
    v_output                 VARCHAR2(2000):=NULL;
    v_output_type            CHAR(1):='B';
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

    IF '&DAYS' IS NOT NULL
    THEN
      v_days := '&DAYS';
    ELSE
      v_days := '1';
    END IF;

    IF '&OUTPUT_TYPE' IS NOT NULL
    THEN
      v_output_type := '&OUTPUT_TYPE';
    ELSE
      v_output_type := 'B';
    END IF;

    -- DBMS_OUTPUT.PUT_LINE('Debug Second parameter is ' || v_output_type);
    IF (v_output_type <> 'B') AND (v_output_type <> 'V')
    THEN
        DBMS_OUTPUT.PUT_LINE('Invalid second parameter. Defaulting to basic mode');
        v_output_type := 'B';
    END IF;

    IF (v_days = 1)
    THEN
        v_daystring := 'day';
    ELSE
        v_daystring := 'days';
    END IF;

    SELECT log_mode 
    INTO   v_log_mode
    FROM   v$database;

    IF (v_days = 0)
    THEN
        DBMS_OUTPUT.PUT_LINE('** RMAN checks currently disabled for ' || v_database || ' **');
    ELSIF (v_log_mode = 'NOARCHIVELOG')
    THEN
        DBMS_OUTPUT.PUT_LINE('** Database is in NOARCHIVELOG Mode. No RMAN checks will be run for ' || v_database || ' **');
    ELSE
        -- Two error conditions are checked:
        --
        --  1) No recent backup
        --  2) Last ARCHIVELOG or DB backup failed
        --
        SELECT COUNT(*)
        INTO  v_count
        FROM  V$RMAN_BACKUP_JOB_DETAILS 
        WHERE start_time > TRUNC(sysdate)-v_days
        AND   status IN ('COMPLETED', 'COMPLETED WITH WARNINGS')
        AND   (input_type LIKE 'DB%') OR (input_type = 'ARCHIVELOG');

        IF (v_count < 1)
        THEN
            DBMS_OUTPUT.PUT_LINE('** ERROR: No RMAN backups for ' || v_database || v_environment || ' in the last ' || v_days || ' ' || v_daystring || ' (at least) **');

            SELECT MAX(start_time)
            INTO   v_last_backup
            FROM   V$RMAN_BACKUP_JOB_DETAILS
            WHERE  input_type LIKE 'DB%'
            AND    status IN ('COMPLETED', 'COMPLETED WITH WARNINGS')
            AND    input_type like 'DB%';

            IF (v_last_backup IS NULL)
            THEN
                DBMS_OUTPUT.PUT_LINE('--        N.B. No database backups found in the controlfile.');
            END IF;
	     
        ELSE
            SELECT rman_summary, status
            INTO v_rman_summary, v_status
            FROM (
            SELECT  TO_CHAR(start_time, 'Day')
             || ' ' || TO_CHAR(start_time, 'dd Mon yyyy (hh24:mi:ss)') || ' => '
             || TO_CHAR(end_time, '(hh24:mi:ss)') || ' - ('
             || input_type || ': Backup ' || status || ')' AS rman_summary, rownum, status, start_time
            FROM V$RMAN_BACKUP_JOB_DETAILS
            WHERE ((input_type like 'DB %') OR (input_type = 'ARCHIVELOG'))
            AND start_time > TRUNC(sysdate)-v_days
	    AND status <> 'RUNNING'
            ORDER BY end_time DESC)
            WHERE rownum=1;

            IF (v_status IN ('COMPLETED', 'COMPLETED WITH WARNINGS'))
            THEN
                DBMS_OUTPUT.PUT_LINE('** No RMAN alerts for ' || v_database || v_environment || ' in the last ' || v_days || ' ' || v_daystring || ' (at least) **');
            ELSE
                DBMS_OUTPUT.PUT_LINE('** ERROR ' || v_rman_summary || ' on ' || v_database || v_environment || ' in the last ' || v_days || ' ' || v_daystring || ' (at least) **');
            END IF;
        END IF; 
    
	for c1 IN (
		WITH 
		lfb AS
    		(SELECT '--    Last Full backup:               ' || TO_CHAR(GREATEST(start_time), 'Day DD Month YYYY HH12:MI:SS (am)') || ' Status: ' || status AS message
    		FROM (SELECT j.status, j.start_time
    		FROM V$BACKUP_SET_DETAILS d,
         		V$RMAN_BACKUP_JOB_DETAILS j
    		WHERE d.incremental_level IS NOT NULL
    		AND   d.start_time > sysdate -7
    		AND   j.session_key = d.session_key
    		AND   j.session_recid = d.session_recid
    		AND   j.input_type like 'DB%'
    		AND   d.incremental_level = 0
    		ORDER BY d.start_time DESC)
    		WHERE ROWNUM = 1),
		lib AS
    		(SELECT '--    Last Incremental backup:        ' || TO_CHAR(GREATEST(start_time), 'Day DD Month YYYY HH12:MI:SS (am)') || ' Status: ' || RPAD(status,10)  || ' (1 week check)' AS message
    		FROM (SELECT j.status, j.start_time
    		FROM V$BACKUP_SET_DETAILS d,
         		V$RMAN_BACKUP_JOB_DETAILS j
    		WHERE d.incremental_level IS NOT NULL
    		AND   d.start_time > sysdate -7
    		AND   j.session_key = d.session_key
    		AND   j.session_recid = d.session_recid
    		AND   j.input_type like 'DB%'
    		AND   d.incremental_level = 1
    		ORDER BY d.start_time DESC)
    		WHERE ROWNUM = 1),
		lab AS
    		(SELECT '--    Last Archivelog backup:         ' || TO_CHAR(GREATEST(start_time), 'Day DD Month YYYY HH12:MI:SS (am)') || ' Status: ' || RPAD(status,10) || ' (1 week check)' AS message
    		FROM (SELECT j.status, j.start_time
    		FROM  V$RMAN_BACKUP_JOB_DETAILS j
    		WHERE    j.input_type like 'ARC%'
    		AND      j.start_time > sysdate -7
    		ORDER BY j.start_time DESC)
    		WHERE ROWNUM = 1),
		flfb AS
    		(SELECT '--    Last Database Backup FAILURE:   ' || TO_CHAR(GREATEST(start_time), 'Day DD Month YYYY HH12:MI:SS (am)') || ' Status: ' || RPAD(status,10) || ' (1 month check)' AS message
    		FROM (SELECT j.status, j.start_time
    		FROM  V$RMAN_BACKUP_JOB_DETAILS j
    		WHERE j.input_type like 'DB%'
    		AND j.start_time > sysdate -32
    		AND   j.status = 'FAILED'
    		ORDER BY j.start_time DESC)
    		WHERE ROWNUM = 1),
		flab AS
    		(SELECT '--    Last Archivelog Backup FAILURE: ' || TO_CHAR(GREATEST(start_time), 'Day DD Month YYYY HH12:MI:SS (am)') || ' Status: ' || RPAD(status,10) || ' (1 month check)' AS message
    		FROM (SELECT j.status, j.start_time
    		FROM  V$RMAN_BACKUP_JOB_DETAILS j
    		WHERE j.input_type like 'ARC%'
    		AND   j.start_time > sysdate -32
    		AND   j.status = 'FAILED'
    		ORDER BY j.start_time DESC)
    		WHERE ROWNUM = 1)
		SELECT message FROM lfb 
		UNION ALL SELECT message FROM lib
		UNION ALL SELECT message FROM lab
		UNION ALL SELECT message FROM flfb
		UNION ALL SELECT message FROM flab)
	LOOP	
                DBMS_OUTPUT.PUT_LINE(c1.message);
        END LOOP;
    END IF; 
    END;
/
