set pages 1000
set lines 220
set feedback off

SET VERIFY OFF
SET TERMOUT OFF
SET FEEDBACK OFF

COLUMN v_db new_value DATABASE_NAME noprint

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

SELECT DECODE(UPPER('&1'),'ALL','%',UPPER('&1')) AS v_db
FROM dual;

SET TERMOUT ON
SET SERVEROUTPUT ON FORMAT WRAPPED

COL spacetime      heading "Time"
COL b1             heading " "
COL b2             heading " "
COL fifteenav      heading "15 min avg"
COL fifteenmin     heading "-15 min"
COL fivemin        heading "-5 min"
COL fortyfivemin   heading "-45 min"
COL hourav         heading "Hour avg"
COL metric         format a32 heading "Metric"
COL nowcol         heading "Now"
COL sixhrav        heading "6 Hr avg"
COL sixtymin       heading "-60 min"
COL tenmin         heading "-10 min"
COL thirtymin      heading "-30 min"
COL todayav        heading "Today avg"
COL twohrav        heading "2 Hr avg"
COL ydayav         heading "Y-Day avg"

DECLARE
    v_database_name     amo.am_metric_hist.database_name%TYPE;
    v_server            amo.am_metric_hist.server%TYPE;
    v_heading           VARCHAR2(2000):='Metric                           Time                     Now       -5 min     -10 min     -15 min     -30 min     -45 min    -60 min       15 min avg   Hour avg    2 Hr avg    6 Hr avg   Today avg   Y-Day avg';
    v_underline         VARCHAR2(2000):='=================================================================================================================================================================================================================';

BEGIN
 FOR c1 IN (
 WITH s1 AS (SELECT
    z.database_name,
    z.server,
    z.metric,
    z.space_time,
    z.now_value,
    z.min1_value,
    z.min2_value,
    z.min3_value,
    z.min6_value,
    z.min9_value,
    z.min12_value
 FROM
    (SELECT  database_name,
             server,
             metric,
             space_time,
             value AS now_value,
             LAG(value, 1, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min1_value,
             LAG(value, 2, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min2_value,
             LAG(value, 3, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min3_value,
             LAG(value, 6, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min6_value,
             LAG(value, 9, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min9_value,
             LAG(value, 12, NULL) OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min12_value,
             ROW_NUMBER() OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time desc) AS rn
      FROM   amo.am_metric_hist) z
 WHERE z.rn = 1
 GROUP BY z.database_name, z.server, z.metric, z.space_time, z.now_value, 
          z.min1_value, z.min2_value, z.min3_value, min6_value, min9_value, min12_value
 ORDER BY z.database_name, z.server, z.metric, z.space_time),
s2 AS ( SELECT
    t.database_name,
    t.server,
    t.metric,
    m.now_value,
    f.qtrhour_av,
    h.hday_av,
    w.twohour_av,
    s.sixhour_av,
    t.today_av,
    y.yday_av
 FROM
    (SELECT  database_name,
             server,
             metric,
             AVG(value) AS now_value
      FROM   amo.am_metric_hist
      WHERE  space_time > sysdate - 6/1440
      GROUP BY database_name, server, metric) m,
      (SELECT  database_name,
             server,
             metric,
             AVG(value) AS qtrhour_av
      FROM   amo.am_metric_hist
      WHERE  space_time > sysdate - 15/1440
      GROUP BY database_name, server, metric) f,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS yday_av
       FROM   amo.am_metric_hist
       WHERE  space_time < trunc(sysdate) and space_time > trunc(sysdate) -2
       GROUP BY database_name, server, metric) y,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS hday_av
       FROM   amo.am_metric_hist
       WHERE  space_time < (sysdate +1/24) 
       AND    space_time >= (sysdate -1/24)
       GROUP BY database_name, server, metric) h,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS twohour_av
       FROM   amo.am_metric_hist
       WHERE  space_time < (sysdate +1/24) 
       AND    space_time >= (sysdate -2/24)
       GROUP BY database_name, server, metric) w,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS sixhour_av
       FROM   amo.am_metric_hist
       WHERE  space_time < (sysdate +1/24) 
       AND    space_time >= (sysdate -6/24)
       GROUP BY database_name, server, metric) s,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS today_av
       FROM   amo.am_metric_hist
       WHERE  space_time > TRUNC(sysdate)
       GROUP BY database_name, server, metric) t
 WHERE t.database_name = y.database_name (+)
 AND   t.server = y.server (+)
 AND   t.metric = y.metric (+)
 AND   t.database_name = f.database_name (+)
 AND   t.server = f.server (+)
 AND   t.metric = f.metric (+)
 AND   t.database_name = h.database_name (+)
 AND   t.server = h.server (+)
 AND   t.metric = h.metric (+)
 AND   t.database_name = m.database_name (+)
 AND   t.server = m.server (+)
 AND   t.metric = m.metric (+)
 AND   t.database_name = w.database_name (+)
 AND   t.server = w.server (+)
 AND   t.metric = w.metric (+)
 AND   t.database_name = s.database_name (+)
 AND   t.server = s.server (+)
 AND   t.metric = s.metric (+)
 GROUP BY t.database_name, t.server, t.metric, m.now_value, f.qtrhour_av, y.yday_av, h.hday_av, t.today_av, w.twohour_av, s.sixhour_av
 ORDER BY t.database_name, t.server, t.metric),
z as (SELECT 
    s1.database_name,
    s2.server,
    s1.metric,
    TO_CHAR(s1.space_time,'DD-MM-YY hh24:mi:ss') AS spacetime,
    '|'            AS b1,
    s1.now_value   AS nowcol,
    s1.min1_value  AS fivemin,
    s1.min2_value  AS tenmin,
    s1.min3_value  AS fifteenmin,
    s1.min6_value  AS thirtymin,
    s1.min9_value  AS fortyfivemin,
    s1.min12_value AS sixtymin,
    '|'            AS b2,
    s2.qtrhour_av  AS fifteenav,
    s2.hday_av     AS hourav,
    s2.twohour_av  AS twohrav,
    s2.sixhour_av  AS sixhrav,
    s2.today_av    AS todayav,
    s2.yday_av     AS ydayav
FROM s1, s2
WHERE s1.metric=s2.metric
AND s1.space_time > sysdate -1/24
AND s1.database_name = s2.database_name
AND s1.server = s2.server
ORDER BY 1)
SELECT RPAD(metric,32) || ' ' || 
       RPAD(spacetime,20) || b1 || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( nowcol,       '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( fivemin,      '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( tenmin,       '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( fifteenmin,   '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( thirtymin,    '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( fortyfivemin, '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( sixtymin,     '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       b2 || ' ' || 
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( fifteenav,    '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( hourav,       '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( twohrav,      '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( sixhrav,      '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( todayav,      '9.99EEEE' ))),11),'   N/A     ') || ' ' ||
       NVL(RPAD(TO_CHAR(TO_NUMBER( TO_CHAR( ydayav,       '9.99EEEE' ))),11),'   N/A     ') AS metricstring,
       database_name,
       server
FROM z
WHERE database_name LIKE '&DATABASE_NAME' ORDER by 2,3,1)
LOOP
     IF (v_server <> c1.server) OR (v_database_name <> c1.database_name) OR (v_server IS NULL)
     THEN
         DBMS_OUTPUT.PUT_LINE(CHR(07));
         DBMS_OUTPUT.PUT_LINE('Metrics for ' || c1.database_name || ' Running on ' || c1.server);
         DBMS_OUTPUT.PUT_LINE(CHR(07));
         DBMS_OUTPUT.PUT_LINE(v_heading);
         DBMS_OUTPUT.PUT_LINE(v_underline);
     END IF;
     DBMS_OUTPUT.PUT_LINE(c1.metricstring);
     v_database_name := c1.database_name;
     v_server := c1.server;
END LOOP;
END;
/

