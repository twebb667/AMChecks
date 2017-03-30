SET LINES 200
--SET PAGES 0
SET NUMF 999,999,999,999
set serveroutput on

COL instance_started FORMAT A80 HEADING "Instance Started"
COL uptime           FORMAT A55 HEADING "Uptime"

DECLARE
    v_string1 VARCHAR2(100);
    v_string2 VARCHAR2(100);
    v_string3 VARCHAR2(100);

BEGIN
    SELECT v.instance_name || ' running on ' || NVL(SUBSTR(v.host_name,1, INSTR(v.host_name, '.')-1),v.host_name) AS instance
    INTO v_string1
    FROM sys.v_$instance v;

    SELECT LTRIM(TO_CHAR(SUM(mount_size)/1024/1024/1024,'999,990.99')) AS db_size_in_gig
    INTO v_string2
    FROM  (SELECT SUBSTR(file_name,0,4) mountpoint, SUM(bytes) mount_size
           FROM   dba_data_files
           GROUP BY SUBSTR(file_name,0,4)
           UNION ALL
           SELECT SUBSTR(file_name,0,4), SUM(bytes)
           FROM dba_temp_files
           GROUP BY SUBSTR(file_name,0,4))
    ORDER BY 1;

    SELECT DISTINCT version
    INTO v_string3
    FROM   dba_registry
    WHERE  comp_name LIKE 'Ora%Catalog Views';

    DBMS_OUTPUT.put_line('Instance: ' || v_string1 || ' is ' || v_string2 || ' Gig and is running Oracle version ' || v_string3);
END;
/
exit;
