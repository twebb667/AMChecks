-- Checks for any failed or broken jobs.

-- Tony Webb 24 Nov 2015

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;
--

SET PAGES 1000
SET HEADING off
SET FEEDBACK off
SET LINES 200
SET SERVEROUTPUT on
SET TAB OFF

DECLARE
    v_count          PLS_INTEGER;
    v_jobstring      VARCHAR2(4):='jobs';
    v_output         VARCHAR2(2000):=NULL;

    TYPE t_jobsty IS RECORD (job            dba_jobs.job%TYPE,
                             log_user       dba_jobs.log_user%TYPE,
                             last_date      VARCHAR2(20),
                             broken         VARCHAR2(11),
                             failures       dba_jobs.failures%TYPE,
                             what           dba_jobs.what%TYPE);

    TYPE t_jobst    IS TABLE OF t_jobsty;
    v_jobs          t_jobst;

BEGIN

    SELECT COUNT(*)
    INTO   v_count
    FROM   dba_jobs
    WHERE (broken = 'Y') OR (failures > 0);

    IF (v_count < 1) OR (v_count IS NULL)
    THEN
        DBMS_OUTPUT.PUT_LINE('** No Unsuccessful or Broken Jobs Found **');
    ELSE
        IF (v_count = 1) 
        THEN
            v_jobstring:='job';
        END IF;
        IF (v_count > 10) 
        THEN
            DBMS_OUTPUT.PUT_LINE('** WARNING - ' || TO_CHAR(v_count) || ' broken or failed jobs. ONLY FAILED JOBS will be listed. Please investigate further! **');
            SELECT job,
                   log_user,
                   TO_CHAR(last_date,'dd-Mon-yy HH24:MI:SS') AS last_date,
                   'Broken' AS broken,
                   failures,
                   what
            BULK COLLECT INTO v_jobs
            FROM   dba_jobs
            WHERE (broken = 'Y') AND (failures > 0);
        ELSE
            DBMS_OUTPUT.PUT_LINE('** WARNING - ' || TO_CHAR(v_count) || ' failed or broken ' || v_jobstring || ' found **');
            SELECT job,
                   log_user,
                   TO_CHAR(last_date,'dd-Mon-yy HH24:MI:SS') AS last_date,
                   DECODE(broken,'Y', 'Broken.','Not Broken.') AS broken,
                   failures,
                   what
            BULK COLLECT INTO v_jobs
            FROM   dba_jobs
            WHERE (broken = 'Y') OR (failures > 0);
        END IF;
 
        FOR i IN 1 .. v_jobs.COUNT
        LOOP
            DBMS_OUTPUT.PUT_LINE('**   Job ' || RPAD(TO_CHAR(v_jobs(i).job),8) || ' for ' || TRIM(v_jobs(i).log_user) ||
                                    ' (' || v_jobs(i).last_date || ') ' ||
                                    TRIM(v_jobs(i).broken) || ' ' ||
                                    CASE WHEN TO_CHAR(v_jobs(i).failures) > 0 THEN 'Failures: ' || TO_CHAR(v_jobs(i).failures)
                                         ELSE 'No Failures '
                                    END
                                    || ' - ' || v_jobs(i).what || ' **');
        END LOOP;
    END IF;
END;

/

