SET LINES 200
--SET PAGES 0
-- shows peak of log generation from v$loghistory (basic SQL 'inspired' from Don Burlison via google!)
SET NUMF 999,999,999,999
set serveroutput on

DECLARE
    v_log_mode  v$database.log_mode%TYPE;
    v_string1   VARCHAR2(100);
    v_string2   VARCHAR2(100);

BEGIN
    SELECT v.instance_name || ' running on ' || NVL(SUBSTR(v.host_name,1, INSTR(v.host_name, '.')-1),v.host_name) AS instance
    INTO v_string1
    FROM sys.v_$instance v;

    SELECT d.log_mode
    INTO   v_log_mode
    FROM   v$database d;

    SELECT MAX(daily_avg_mb) 
    INTO   v_string2
    FROM (SELECT a.*,
          ROUND(a.COUNT#*B.AVG#/1024/1024) AS daily_avg_mb
    FROM (SELECT TO_CHAR(first_time,'YYYY-MM-DD') AS day,
                 COUNT(1) AS count#,
                 MIN(RECID) AS min#,
                 MAX(RECID) AS max#
          FROM v$log_history
          GROUP BY TO_CHAR(first_time,'YYYY-MM-DD')
          ORDER BY 1 DESC) A,
          (SELECT AVG(bytes) AS AVG#,
                  COUNT(1) AS count#,
                  MAX(bytes) AS max_bytes,
                  MIN(bytes) AS min_bytes
           FROM v$log) B
           );

    DBMS_OUTPUT.put_line('Instance: ' || v_string1 || ' had ' || v_string2 || ' MB of redo generated in a day (' || v_log_mode | |')');
END;
/
exit;
