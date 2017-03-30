
--
-- Tony Webb 03rd July 2015
--
-- This script expects 1 parameter to be passed - database_name 
-- 'ALL' can be passed as database name and wild-cards can be used for partial database names
--
-- It will list current size of the database(s) from the latest run of 'total_space_checl.ksh'
-- along with growth results for the last month, 6 months and year.
--
-- Updated by Tony Webb 18/08/15 to include monthly figures for the last year.
--

SET TAB OFF
SET LINES 180 PAGES 1000
SET VERIFY OFF
SET TERMOUT OFF
SET HEADING OFF
SET FEEDBACK OFF

COLUMN v_db new_value DATABASE_NAME noprint

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

SELECT DECODE(UPPER('&1'),'ALL','%',UPPER('&1')) AS v_db
FROM dual;

SET TERMOUT ON
SET SERVEROUTPUT ON

PROMPT
PROMPT Database Growth
PROMPT ================

DECLARE
    v_dbname         VARCHAR2(15); 
    v_rec_count      PLS_INTEGER:=0;
    v_rec_count2     PLS_INTEGER:=0;
    v_parameter      VARCHAR2(2000);
BEGIN

DBMS_OUTPUT.PUT_LINE('Database        Date Now      Space (GB)  Last Mth(GB)      Month Growth         6 Mth(GB)      6 Months Growth      Last Yr(GB)      Year Growth');
DBMS_OUTPUT.PUT_LINE('--------------- ------------ ----------- ------------- ----------------------  ------------  --------------------- ------------- ----------------------');
  
FOR c1 IN (
  WITH
    now_size   AS (SELECT  database_name,
                           NVL(gig_used,0) AS now_gig_used,
                           space_time      AS now_space_time,
                           LAST_VALUE(space_time) OVER (PARTITION BY database_name ) AS now_last_space_time
                  FROM     amo.am_total_space
                  WHERE    database_name LIKE '&DATABASE_NAME'
                  ORDER BY database_name, space_time, gig_used
                  ),
    month_size AS (SELECT database_name,
                          NVL(gig_used,0) AS month_gig_used,
                          space_time      AS month_space_time,
                          FIRST_VALUE(space_time) OVER (PARTITION BY database_name ) AS month_first_space_time
                   FROM   amo.am_total_space
                   WHERE space_time > sysdate - 31
                   AND   database_name LIKE '&DATABASE_NAME'
                   ORDER BY database_name, space_time, gig_used
                   ),
    six_month_size AS (SELECT database_name,
                          NVL(gig_used,0) AS six_month_gig_used,
                          space_time      AS six_month_space_time,
                          FIRST_VALUE(space_time) OVER (PARTITION BY database_name ) AS six_month_first_space_time
                   FROM   amo.am_total_space
                   WHERE space_time > sysdate - 183
                   AND   database_name LIKE '&DATABASE_NAME'
                   ORDER BY database_name, space_time, gig_used
                   ),
    year_size  AS (SELECT database_name,
                          NVL(gig_used,0) AS year_gig_used,
                          space_time      AS year_space_time,
                          FIRST_VALUE(space_time) OVER (PARTITION BY database_name ) AS year_first_space_time
                   FROM   amo.am_total_space
                   WHERE space_time > sysdate - 365
                   AND   database_name LIKE '&DATABASE_NAME'
                   ORDER BY database_name, space_time, gig_used
                   )
 SELECT n.database_name,
        n.now_space_time AS date_now,
        LPAD(n.now_gig_used,12) AS now_gig_used,
        CASE
             WHEN (month_gig_used = 0) OR (month_gig_used IS NULL) THEN NULL
             ELSE TO_CHAR((now_gig_used - month_gig_used),'990.90') || '(GB) ' 
                  || (TO_CHAR(((now_gig_used - month_gig_used)/(month_gig_used) * 100 ),'990.90') || '%')
        END AS month_growth,
        month_gig_used,
        CASE
             WHEN (six_month_gig_used = 0) OR (six_month_gig_used IS NULL) THEN NULL
             ELSE TO_CHAR((now_gig_used - six_month_gig_used),'990.90') || '(GB) ' 
                  || (TO_CHAR(((now_gig_used - six_month_gig_used)/(six_month_gig_used) * 100 ),'990.90') || '%')
        END AS six_month_growth,
        six_month_gig_used,
        CASE
             WHEN (year_gig_used = 0) OR (year_gig_used IS NULL) THEN NULL
             ELSE TO_CHAR((now_gig_used - year_gig_used),'990.90') || '(GB) ' 
                  || (TO_CHAR(((now_gig_used - year_gig_used)/(year_gig_used) * 100 ),'990.90') || '%')
        END AS year_growth,
        year_gig_used
    FROM now_size n,
         month_size m,
         six_month_size s,
         year_size y
       WHERE n.now_space_time = n.now_last_space_time
       AND   m.month_space_time = m.month_first_space_time
       AND   s.six_month_space_time = s.six_month_first_space_time
       AND   y.year_space_time = y.year_first_space_time
       AND   m.database_name = n.database_name (+)
       AND   s.database_name = m.database_name (+)
       AND   y.database_name = s.database_name (+)
    ORDER BY database_name
)
LOOP
   DBMS_OUTPUT.PUT_LINE(RPAD(c1.database_name,15) || ' ' ||
                              RPAD(TO_CHAR(c1.date_now,'DD-MON-YY'),10) || ' ' || 
                              LPAD(TO_CHAR(c1.now_gig_used,'999,990.99'),13) || ' ' ||
                              LPAD(TO_CHAR(c1.month_gig_used, '999,990.99'),13) || ' ' || 
                              LPAD(c1.month_growth,22) || ' ' ||
                              LPAD(TO_CHAR(c1.six_month_gig_used, '999,990.99'),13) || ' ' || 
                              LPAD(c1.six_month_growth,22) || ' ' ||
                              LPAD(TO_CHAR(c1.year_gig_used, '999,990.99'),13) || ' ' || 
                              LPAD(c1.year_growth,22));
    v_rec_count:= v_rec_count + 1;
END LOOP;

DBMS_OUTPUT.PUT_LINE(CHR(10));
DBMS_OUTPUT.PUT_LINE('Database         Date            Space (GB)');
DBMS_OUTPUT.PUT('---------------  ----------   --------------');
 
v_dbname:=' '; 
FOR c2 IN ( 
    SELECT database_name,
           monthno,
           gig_used,
           space_date
    FROM   (SELECT database_name,
                   TO_CHAR(space_time,'yymm') AS monthno,
                   TO_CHAR(NVL(gig_used,0),'999,990.90') AS gig_used,
                   TO_CHAR(LAST_VALUE(space_time) OVER (PARTITION BY database_name,  TO_CHAR(space_time,'yymm') ),'DD-MON-YY') AS now_last_space_time,
                   TO_CHAR(space_time,'DD-MON-YY') AS space_date
            FROM   amo.am_total_space
            WHERE  database_name LIKE '&DATABASE_NAME'
            AND    space_time > sysdate -365
            ORDER BY database_name, space_time)
    WHERE  now_last_space_time = space_date
    ORDER BY database_name, monthno ASC
)
LOOP
   IF (v_dbname = c2.database_name)
   THEN
       DBMS_OUTPUT.PUT(RPAD(CHR(15),16));
   ELSE
       DBMS_OUTPUT.PUT(CHR(10)||RPAD(c2.database_name,15));
   END IF;

   DBMS_OUTPUT.PUT_LINE(LPAD(c2.space_date,11) || LPAD(c2.gig_used,18));
   v_dbname:=c2.database_name;
   v_rec_count2:= v_rec_count2 + 1;
END LOOP;

END;
/

PROMPT
PROMPT Note that if historical space details aren't found the details used for the space calculations above
PROMPT will be based on the nearest date since the specified time.
-- PROMPT
