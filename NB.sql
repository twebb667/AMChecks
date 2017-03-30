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
	
	SET TERMOUT ON
	SET SERVEROUTPUT ON
	
	prompt
	prompt OS Space Alerts
	prompt ================
	prompt
	
	DECLARE
    	fileHandler UTL_FILE.FILE_TYPE;

    	TYPE  t_space IS RECORD (server     VARCHAR2(30),
                             	mountpoint VARCHAR2(200),
                               	pctused    NUMBER(3,0),
                               	sizek      NUMBER(10,0), 
                               	usedk      NUMBER(10,0), 
                               	availk     NUMBER(10,0), 
  	                     	space_time DATE);

    	TYPE  t_space_tab IS TABLE OF t_space;
    	v_space t_space_tab := t_space_tab();
    	v_rec_count      PLS_INTEGER:=0;
	
    	v_day_growth_string     VARCHAR2(10);
    	v_week_growth_string    VARCHAR2(10);
    	v_month_growth_string   VARCHAR2(10);
	
	------------------------------------------------------------------
	-- These are the values used to determine the alerting thresholds
	-- for the main select
	------------------------------------------------------------------
	
    	v_threshold_day           PLS_INTEGER:=90;
    	v_threshold_week          PLS_INTEGER:=50;
    	v_threshold_error         PLS_INTEGER:=95;
    	v_threshold_brown_trouser PLS_INTEGER:=98;

	BEGIN

--        v_threshold_day := v_threshold_day - ${WEIGHTING};
--        v_threshold_week := v_threshold_week + ${WEIGHTING};
--        v_threshold_error := v_threshold_error - ${WEIGHTING}/2;
--        v_threshold_brown_trouser := v_threshold_brown_trouser - ${WEIGHTING}/4;

--	DBMS_OUTPUT.PUT_LINE('v_threshold_day is: ' || TO_CHAR(v_threshold_day,'990'));
--	DBMS_OUTPUT.PUT_LINE('v_threshold_week is: ' || TO_CHAR(v_threshold_week,'990'));
--	DBMS_OUTPUT.PUT_LINE('v_threshold_error is: ' || TO_CHAR(v_threshold_error,'990'));
--	DBMS_OUTPUT.PUT_LINE('v_threshold_brown_trouser is: ' || TO_CHAR(v_threshold_brown_trouser,'990'));
	
	fileHandler := UTL_FILE.FOPEN('AMCHECK_TEMP', 'non_oracle_os_space_history.txt', 'W');
	
	DBMS_OUTPUT.PUT_LINE('Server               Mountpoint                               Today Yesterday Last Wk Last Mth Day Growth Wk Growth Mth Growth');
	DBMS_OUTPUT.PUT_LINE('-------------------- ---------------------------------------- ----- --------- ------- -------- ---------- --------- ----------');
	
	FOR c1 IN (
	WITH now_info AS
     	    (SELECT DISTINCT *
     	     FROM (SELECT s.server, s.mountpoint, NVL(s.pctused,0) AS now_pctused, s.space_time AS now_space_time,
                         RANK() OVER (PARTITION BY s.server, s.mountpoint ORDER BY s.server, s.mountpoint, s.space_time DESC) AS my_rownum
                   FROM   amo.am_os_space s
                   WHERE  s.server = 'hatux1p1'
                   AND    s.space_time >= trunc(sysdate))
     	     WHERE   my_rownum = 1
     	     ORDER BY server, mountpoint, now_space_time, now_pctused),
        yesterday_info AS
	(SELECT *
     	     FROM (SELECT s.server, s.mountpoint, NVL(s.pctused,0) AS yesterday_pctused, s.space_time AS yesterday_space_time,
                         RANK() OVER (PARTITION BY s.server, s.mountpoint ORDER BY s.server, s.mountpoint, s.space_time DESC) AS my_rownum
                   FROM   amo.am_os_space s
                   WHERE  s.server = 'hatux1p1'
            	   AND    s.space_time < trunc(sysdate) AND s.space_time >= trunc(sysdate-7))
     	     WHERE   my_rownum = 1
             ORDER BY server, mountpoint, yesterday_space_time, yesterday_pctused),
	lastweek_info AS
    	(SELECT *
     	     FROM (SELECT s.server, s.mountpoint, NVL(s.pctused,0) AS lastweek_pctused, s.space_time AS lastweek_space_time,
                         RANK() OVER (PARTITION BY s.server, s.mountpoint ORDER BY s.server, s.mountpoint, s.space_time DESC) AS my_rownum
                   FROM   amo.am_os_space s
                   WHERE  s.server = 'hatux1p1'
      		AND     s.space_time <= trunc(sysdate-7) AND s.space_time >= trunc(sysdate-13))
     	        WHERE   my_rownum = 1
            	ORDER BY server, mountpoint, lastweek_space_time, lastweek_pctused),
	lastmonth_info AS
    	(SELECT *
     	     FROM (SELECT s.server, s.mountpoint, NVL(s.pctused,0) AS lastmonth_pctused, s.space_time AS lastmonth_space_time,
                         RANK() OVER (PARTITION BY s.server, s.mountpoint ORDER BY s.server, s.mountpoint, s.space_time DESC) AS my_rownum
                   FROM   amo.am_os_space s
                   WHERE  s.server = 'hatux1p1'
            	AND     s.space_time <= trunc(sysdate-13) AND s.space_time >= trunc(sysdate-62))
     	        WHERE   my_rownum = 1
            	ORDER BY server, mountpoint, lastmonth_space_time, lastmonth_pctused)
	SELECT DISTINCT server,
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
       	status,
        status_brief
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
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_brown_trouser) AND 
                     (n.now_pctused > l.lastweek_pctused) THEN 'Error: Weekly growth (Brown)'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_error) AND 
                     (n.now_pctused > l.lastweek_pctused +2 ) THEN 'Error: Weekly growth (Red)'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_week) AND 
                     ((100 - n.now_pctused) < (n.now_pctused - l.lastweek_pctused)) THEN 'Error: Weekly growth (Amber)'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (y.yesterday_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_day) AND 
                     ((100 - n.now_pctused) < (n.now_pctused - y.yesterday_pctused)) THEN 'Error: Daily growth (Amber)'
           	ELSE 'OK'
       	END) AS status,
       	(CASE 
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_brown_trouser) AND 
                     (n.now_pctused > l.lastweek_pctused) THEN '*ERROR'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_error) AND 
                     (n.now_pctused > l.lastweek_pctused +2 ) THEN '*ERROR*'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_week) AND 
                     ((100 - n.now_pctused) < (n.now_pctused - l.lastweek_pctused)) THEN '*ERROR*'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (y.yesterday_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_day) AND 
                     ((100 - n.now_pctused) < (n.now_pctused - y.yesterday_pctused)) THEN '*ERROR*'
           	ELSE ' '
       	END) AS status_brief
	FROM   now_info n,
       		yesterday_info y,
       		lastweek_info l,
       		lastmonth_info m
--	WHERE  n.server = y.server (+)
--	AND    n.mountpoint = y.mountpoint(+)
--	AND    n.server = l.server (+)
--	AND    n.mountpoint = l.mountpoint (+)
--	AND    n.server = m.server (+)
--	AND    n.mountpoint = m.mountpoint (+)
	WHERE  n.server = y.server (+)
	AND    n.mountpoint = y.mountpoint(+)
	AND    n.server = l.server (+)
	AND    n.mountpoint = l.mountpoint (+)
	AND    n.server = m.server (+)
	AND    n.mountpoint = m.mountpoint (+)
	)
--	WHERE status like 'Error%' or (1=1) 
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
                        	LPAD(v_month_growth_string,10) ||
                                ' ' || c1.status_brief);
    	v_rec_count:= v_rec_count + 1;
	
    	-- Dump out recent space records for each server+mountpoint should it be needed later (verbose mode)
    	-- I should probably make the code aware of the verbose indicator here as a future enhancement.
    	-- Note that BULK COLLECT will overwrite previous iterations so I'm writing to a file.
	
    	SELECT  server, mountpoint, pctused, sizek, usedk, availk, space_time 
    	BULK COLLECT INTO v_space
    	FROM    amo.am_os_space
    	WHERE   server = c1.server
    	AND     mountpoint = c1.mountpoint
    	AND     space_time > trunc(sysdate)-14;
	
    	if (v_space.COUNT > 0)
    	then
        	FOR ix IN v_space.FIRST .. v_space.LAST 
        	LOOP
           	UTL_FILE.PUTF(fileHandler, RPAD(v_space(ix).server,20) || ' ' ||
                                      	RPAD(v_space(ix).mountpoint,40) || ' ' || 
                                      	RPAD(TO_CHAR(v_space(ix).pctused,'990') || '%' ,6) || ' ' || 
                                      	TO_CHAR(v_space(ix).space_time,'Dy DD-MM-YY HH24:MI:SS') || '\n');
        	END LOOP;
    	end if;
    	UTL_FILE.PUTF(fileHandler, '\n');
	
	END LOOP;
	
  	UTL_FILE.FCLOSE(fileHandler);
	
	EXCEPTION
  	WHEN utl_file.invalid_path THEN
     	raise_application_error(-20000, 'ERROR: Invalid PATH FOR file.');
	END;
	/

