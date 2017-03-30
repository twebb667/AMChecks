-- Tony Webb 10th May 2016
WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

SET FEEDBACK OFF;
SET SERVEROUTPUT ON
SET LINES 200

DECLARE
    v_alert_log         VARCHAR2(200);
    v_enterprise_count  PLS_INTEGER:=0;
    v_enterprise_string VARCHAR2(30):='Standard Edition';
    v_host_name         v$instance.host_name%TYPE;
    v_instance_name     v$instance.instance_name%TYPE;
    v_log_mode          v$database.log_mode%TYPE;
    v_platform          VARCHAR2(200):=NULL;
    v_uptime_info       VARCHAR2(200):=NULL;
    v_version           VARCHAR2(80):=NULL;
BEGIN

SELECT v.instance_name,
       v.host_name,
       TO_CHAR(v.startup_time, 'Dy ddth Mon YYYY hh24:mi:ss') || ' (' || TO_CHAR(FLOOR((SYSDATE-v.startup_time)) || ' Days ' || 
                 MOD(FLOOR((SYSDATE-v.startup_time)*24),24) || ' Hours ' ||
                 MOD(FLOOR((SYSDATE-v.startup_time)*24*60),60) || ' Minutes '|| 
                 MOD(FLOOR((SYSDATE-v.startup_time)*24*60*60),60) || ' Seconds' ||')') AS uptime_info
INTO   v_instance_name,
       v_host_name,
       v_uptime_info
FROM     v$instance v 
ORDER BY v.instance_name;

SELECT COUNT(*)
INTO   v_enterprise_count
FROM   v$version 
WHERE  banner LIKE '%Enterprise Edition%';

SELECT value || '/alert_' || instance_name || '.log' 
INTO  v_alert_log
FROM  v$parameter, 
      v$instance 
WHERE name='background_dump_dest';

SELECT d.log_mode,
       d.platform_name || ' ' || t.endian_format || ' Endian' 
INTO   v_log_mode,
       v_platform
FROM   v$database d,
       v$transportable_platform t
WHERE  d.platform_id = t.platform_id;

SELECT DISTINCT version 
INTO   v_version
FROM   dba_registry 
WHERE  comp_name LIKE 'Ora%Catalog Views';

IF (v_enterprise_count > 0)
THEN
    v_enterprise_string := 'Enterprise Edition';
END IF;

DBMS_OUTPUT.PUT_LINE (CHR(10) || v_instance_name || ' (' || v_enterprise_string || ' - ' || v_version || ') running on ' || v_host_name || ' (' || v_platform || ') in ' || v_log_mode || ' mode' || CHR(10));

DBMS_OUTPUT.PUT_LINE ('Started on ' || v_uptime_info || CHR(10));
DBMS_OUTPUT.PUT_LINE (RPAD('Alert log',20) || ' => ' || v_alert_log);

FOR c1 IN (SELECT RPAD(name,20) || ' => ' || value AS dest
FROM v$parameter 
WHERE name LIKE 'log_archive_dest%'
AND value IS NOT NULL
AND name NOT LIKE '%state%')
LOOP
    DBMS_OUTPUT.PUT_LINE (c1.dest);
END LOOP;

-- DBMS_OUTPUT.PUT_LINE (CHR(10));
END;
/

