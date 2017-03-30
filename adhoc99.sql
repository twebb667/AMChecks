SET LINES 140
SET PAGES 0

COL instance_started FORMAT A80 HEADING "Instance Started"
COL uptime           FORMAT A55 HEADING "Uptime"

SELECT v.instance_name || ' running on ' || NVL(SUBSTR(v.host_name,1, INSTR(v.host_name, '.')-1),v.host_name) || ' started on ' ||
       TO_CHAR(v.startup_time, 'Dy ddth Mon YYYY "at" hh24:mi:ss') AS instance_started,
       '(up ' || TO_CHAR(FLOOR((SYSDATE-v.startup_time)) || ' Days ' ||
                  MOD(FLOOR((SYSDATE-v.startup_time)*24),24) || ' Hours ' ||
                  MOD(FLOOR((SYSDATE-v.startup_time)*24*60),60) || ' Minutes '||
                  MOD(FLOOR((SYSDATE-v.startup_time)*24*60*60),60) || ' Seconds' ||')') AS uptime
FROM sys.v_$instance v;

exit;

