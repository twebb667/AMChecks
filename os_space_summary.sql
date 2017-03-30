--
-- OS space details (if any can be found) for a database.
-- A mandatory parameter of database name should be passed to this script.
--
-- Author: Tony Webb 02/02/16
--
-- The code here is mostly ripped from all_os_space_check.ksh
-- ..they should really be consolidated!
-- 
-- physical_server changes 12/07/16
--

SET PAGES 1000
SET FEEDBACK OFF
SET LINES 150
COL day_growth               FORMAT 990 
COL day_growth_string        FORMAT A10 HEADING 'Day Growth'
COL month_growth             FORMAT 990 
COL month_growth_string      FORMAT A8 HEADING 'Mth Growth'
COL mountpoint               FORMAT A40 HEADING 'Mountpoint'
COL now_pctused              FORMAT 990 
COL now_pctused_string       FORMAT A5 HEADING 'Today'
COL lastmonth_pctused_string FORMAT A8 HEADING 'Last Mth'
COL lastweek_pctused_string  FORMAT A7 HEADING 'Last Wk'
COL server                   FORMAT A20 HEADING 'Server'
COL week_growth              FORMAT 990 
COL week_growth_string       FORMAT A7 HEADING 'Wk Growth'
COL yesterday_pctused_string FORMAT A9 HEADING 'Yesterday'

SET VERIFY OFF
SET TERMOUT OFF
COLUMN 1 new_value 1
SELECT ''  AS "1" FROM dual WHERE ROWNUM = 0;
DEFINE PARAM1 = '&1'
SET TERMOUT ON
SET SERVEROUTPUT ON

prompt
prompt OS Space Details
prompt =================
prompt

DECLARE

    v_day_growth_string     VARCHAR2(10);
    v_month_growth_string   VARCHAR2(10);
    v_week_growth_string    VARCHAR2(10);

------------------------------------------------------------------
-- These are the values used to determine the alerting thresholds
-- for the main select
------------------------------------------------------------------

    v_threshold_day           PLS_INTEGER:=90;
    v_threshold_week          PLS_INTEGER:=50;
    v_threshold_error         PLS_INTEGER:=95;
    v_threshold_brown_trouser PLS_INTEGER:=98;

    v_rowcount                PLS_INTEGER:=0;

BEGIN

DBMS_OUTPUT.PUT_LINE('Server               Mountpoint                               Today Yesterday Last Wk Last Mth Day Growth Wk Growth Mth Growth Alert');
DBMS_OUTPUT.PUT_LINE('-------------------- ---------------------------------------- ----- --------- ------- -------- ---------- --------- ---------- --------------------');

FOR c1 IN (
WITH now_info AS
     (SELECT *
      FROM (SELECT  s.server,
                    s.mountpoint,
                    NVL(s.pctused,0) AS now_pctused,
                    s.space_time     AS now_space_time,
                    LAST_VALUE(s.space_time) OVER (PARTITION BY s.server, s.mountpoint) AS now_last_space_time
            FROM    amo.am_os_space s,
		    amo.am_server z,
                    amo.am_database d
	    WHERE   s.server = z.physical_server_abbrev
	    AND     z.server = d.server
            AND     d.database_name like UPPER(DECODE('&PARAM1', '', '%', '&PARAM1'))
            AND     s.space_time >= trunc(sysdate))
            WHERE   now_last_space_time = now_space_time
            ORDER BY server, mountpoint, now_space_time, now_pctused),
yesterday_info AS
(SELECT *
     FROM (SELECT   s.server,
                    s.mountpoint,
                    NVL(s.pctused,0) AS yesterday_pctused,
                    s.space_time     AS yesterday_space_time,
                    LAST_VALUE(s.space_time) OVER (PARTITION BY s.server, s.mountpoint) AS yesterday_last_space_time
            FROM    amo.am_os_space s,
		    amo.am_server z,
                    amo.am_database d
	    WHERE   s.server = z.physical_server_abbrev
	    AND     z.server = d.server
            AND     d.database_name like UPPER(DECODE('&PARAM1', '', '%', '&PARAM1'))
            AND     s.space_time < trunc(sysdate) AND s.space_time >= trunc(sysdate-7))
            WHERE   yesterday_last_space_time = yesterday_space_time
            ORDER BY server, mountpoint, yesterday_space_time, yesterday_pctused),
lastweek_info AS
    (SELECT *
     FROM (SELECT   s.server,
                    s.mountpoint,
                    NVL(s.pctused,0) AS lastweek_pctused,
                    s.space_time     AS lastweek_space_time,
                    LAST_VALUE(s.space_time) OVER (PARTITION BY s.server, s.mountpoint) AS lastweek_last_space_time
            FROM    amo.am_os_space s,
		    amo.am_server z,
                    amo.am_database d
	    WHERE   s.server = z.physical_server_abbrev
	    AND     z.server = d.server
            AND     d.database_name like UPPER(DECODE('&PARAM1', '', '%', '&PARAM1'))
            AND     s.space_time <= trunc(sysdate-7) AND s.space_time >= trunc(sysdate-13))
            WHERE   lastweek_last_space_time = lastweek_space_time
            ORDER BY server, mountpoint, lastweek_space_time, lastweek_pctused),
lastmonth_info AS
    (SELECT *
     FROM (SELECT   s.server,
                    s.mountpoint,
                    NVL(s.pctused,0) AS lastmonth_pctused,
                    s.space_time     AS lastmonth_space_time,
                    LAST_VALUE(s.space_time) OVER (PARTITION BY s.server, s.mountpoint) AS lastmonth_last_space_time
            FROM    amo.am_os_space s,
		    amo.am_server z,
                    amo.am_database d
	    WHERE   s.server = z.physical_server_abbrev
	    AND     z.server = d.server
	    AND     d.os_checks_ind = 'Y'
            AND     d.database_name like UPPER(DECODE('&PARAM1', '', '%', '&PARAM1'))
            AND     s.space_time <= trunc(sysdate-13) AND s.space_time >= trunc(sysdate-62))
            WHERE   lastmonth_last_space_time = lastmonth_space_time
            ORDER BY server, mountpoint, lastmonth_space_time, lastmonth_pctused)
SELECT server,
       mountpoint,
       ' ' ||    now_pctused || '%'       AS now_pctused_string,
       '   ' ||  yesterday_pctused || '%' AS yesterday_pctused_string,
       '  ' ||   lastweek_pctused || '%'  AS lastweek_pctused_string,
       '  ' ||   lastmonth_pctused || '%' AS lastmonth_pctused_string,
       '    ' || day_growth || '%'        AS day_growth_string,
       '   ' ||  week_growth || '%'       AS week_growth_string,
       '   ' ||  month_growth || '%'      AS month_growth_string,
       noydata,
       nolwdata,
       nolmdata,
       status
FROM (
SELECT n.server,
       n.mountpoint,
       n.now_pctused,
       DECODE(y.yesterday_pctused,NULL,'*',' ') AS noydata,
       DECODE(l.lastweek_pctused,NULL,'*',' ') AS nolwdata,
       DECODE(m.lastmonth_pctused,NULL,'*',' ') AS nolmdata,
       NVL(y.yesterday_pctused, 0) AS yesterday_pctused,
       NVL(l.lastweek_pctused, NVL(y.yesterday_pctused, 0)) AS lastweek_pctused,
       NVL(m.lastmonth_pctused, NVL(l.lastweek_pctused, NVL(y.yesterday_pctused, 0))) AS lastmonth_pctused,
       NVL((n.now_pctused - NVL(y.yesterday_pctused, 0)),0) AS day_growth,
       NVL((n.now_pctused - NVL(l.lastweek_pctused, NVL(y.yesterday_pctused, 0))),0)  AS week_growth,
       NVL((n.now_pctused - NVL(m.lastmonth_pctused, NVL(l.lastweek_pctused, NVL(y.yesterday_pctused, 0)))),0)  AS month_growth,
       (CASE 
           WHEN NVL(n.now_pctused,0) > v_threshold_brown_trouser AND (NVL(n.now_pctused,0) > NVL(l.lastweek_pctused,0)) THEN 'Error: Weekly growth'
           WHEN NVL(n.now_pctused,0) > v_threshold_error AND (NVL(n.now_pctused,0) > (NVL(l.lastweek_pctused,0)+2)) THEN 'Error: Weekly growth'
           WHEN NVL(n.now_pctused,0) > v_threshold_week  AND (100 - NVL(n.now_pctused,0) < (NVL(n.now_pctused - l.lastweek_pctused,0))) THEN 'Error: Weekly growth'
           WHEN NVL(n.now_pctused,0) > v_threshold_day   AND (100 - NVL(n.now_pctused,0) < (NVL(n.now_pctused - y.yesterday_pctused,0))) THEN 'Error: Daily growth'
           ELSE 'OK'
       END) AS status
FROM   now_info n,
       yesterday_info y,
       lastweek_info l,
       lastmonth_info m
WHERE  n.server = y.server (+)
AND    n.mountpoint = y.mountpoint(+)
AND    n.server = l.server (+)
AND    n.mountpoint = l.mountpoint (+)
AND    n.server = m.server (+)
AND    n.mountpoint = m.mountpoint (+)
)
ORDER BY server
)
LOOP
   if (c1.noydata = '*')
   then
       v_day_growth_string := '(N/A)';      
   else
       v_day_growth_string := c1.day_growth_string;
   end if;

   if (c1.nolwdata = '*')
   then
       v_week_growth_string := '(N/A)';      
   else
       v_week_growth_string := c1.week_growth_string;
   end if;

   if (c1.nolmdata = '*')
   then
       v_month_growth_string := '(N/A)';      
   else
       v_month_growth_string := c1.month_growth_string;
   end if;

   DBMS_OUTPUT.PUT_LINE(RPAD(c1.server,20) || ' ' ||
                        RPAD(c1.mountpoint,40) || ' ' ||
                        LPAD(c1.now_pctused_string,5) || ' ' ||
                        LPAD(c1.yesterday_pctused_string,9) || ' ' ||
                        LPAD(c1.lastweek_pctused_string,7) || ' ' ||
                        LPAD(c1.lastmonth_pctused_string,8) || ' ' ||
                        LPAD(v_day_growth_string,10) || ' ' ||
                        LPAD(v_week_growth_string,9) || ' ' ||
                        LPAD(v_month_growth_string,10) || ' ' ||
                        c1.status);

    v_rowcount := v_rowcount + 1;

END LOOP;

if (v_rowcount = 0)
then
   DBMS_OUTPUT.PUT_LINE('** No data found! Consider enabling OS space checks for this database server. **');
end if;

END;
/
