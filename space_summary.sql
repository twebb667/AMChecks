PROMPT Tablespace Space Usage
PROMPT ======================
--
-- Based on something from the Ask Tom website, tarted up by Tony Webb April 2015
-- Parameterised snd PL/SQL-ized by Tony Webb June 2015
-- Nov 2015 - Now accepting a second paramter of threshold for reporting (percentage)
--
SET TAB OFF
SET LINES 200 PAGES 1000

SET VERIFY OFF
SET TERMOUT OFF
COLUMN 1 new_value 1
COLUMN 2 new_value 2
SELECT ''  AS "1", 0 AS "2" FROM dual WHERE ROWNUM = 0;
DEFINE PARAM1 = '&1'
DEFINE PARAM2 = '&2'
SET TERMOUT ON

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

SET HEADING off
SET FEEDBACK off
SET SERVEROUTPUT on

DECLARE
    v_database       v$database.name%TYPE:=SYS_CONTEXT('USERENV','DB_NAME');
    v_grand_free_mb  NUMBER:=0;
    v_grand_total_mb NUMBER:=0;
    v_grand_used_mb  NUMBER:=0;
    v_percentage     NUMBER:=0;
    v_rec_count      PLS_INTEGER:=0;
    v_parameter      VARCHAR2(2000);
BEGIN

IF '&PARAM2' IS NULL
THEN
    v_percentage := 0;
ELSE
    v_percentage := TO_NUMBER('&PARAM2');
END IF;

DBMS_OUTPUT.PUT_LINE(CHR(08) || '                                                                                             Theory');
DBMS_OUTPUT.PUT_LINE('Tablespace                Size (Mb)  Used (Mb)  Free (Mb)   %Used                          Max (Mb)  %Theory');
DBMS_OUTPUT.PUT_LINE('------------------------ ---------- ---------- ---------- ------- ----------------------- ---------- ------- -----------------------');

FOR c1 IN (
SELECT NVL(b.tablespace_name, NVL(a.tablespace_name,'UNKOWN')) AS tablespace,
       DECODE(t.contents,'UNDO',' (u) ','TEMPORARY',' (t) ','') AS contents,
       mbytes_alloc AS total_mb,
       mbytes_alloc-nvl(mbytes_free,0) AS used_mb,
       NVL(mbytes_free,0) free_mb,
       ((mbytes_alloc-nvl(mbytes_free,0))/ mbytes_alloc)*100 AS pct_used,
       CASE WHEN (mbytes_alloc IS NULL) THEN '['||RPAD(LPAD('OFFLINE',13,'-'),20,'-')||']'
            ELSE '['|| NVL(RPAD(LPAD('X',trunc((ROUND((mbytes_alloc-nvl(mbytes_free,0))/(mbytes_alloc) * 100, 2))/5),'X'),20,'-'),
                       '--------------------')||']'
       END AS GRAPH,
       NVL(mbytes_max,mbytes_alloc) AS Max_Size,
       (mbytes_alloc-NVL(mbytes_free,0))/NVL(mbytes_max,mbytes_alloc)*100 AS pct_max_used,
       CASE WHEN (mbytes_alloc IS NULL) THEN '['||RPAD(LPAD('OFFLINE',13,'-'),20,'-')||']'
            ELSE '['|| NVL(RPAD(LPAD('X',trunc((ROUND((mbytes_alloc-NVL(mbytes_free,0))/NVL(mbytes_max,mbytes_alloc) * 100, 2))/5),'X'),20,'-'),
                       '--------------------')||']'
       END AS GRAPHT
FROM (SELECT SUM(bytes)/1024/1024 AS Mbytes_free,
             MAX(bytes)/1024/1024 AS mb_largest,
             tablespace_name
      FROM   sys.dba_free_space
      GROUP BY tablespace_name ) a,
      dba_tablespaces t,
     (SELECT SUM(bytes)/1024/1024    AS Mbytes_alloc,
             SUM(GREATEST(maxbytes,bytes))/1024/1024 AS Mbytes_max,
             tablespace_name
      FROM   sys.dba_data_files
      GROUP BY tablespace_name
      UNION ALL
      SELECT SUM(bytes)/1024/1024    AS Mbytes_alloc,
             SUM(GREATEST(maxbytes,bytes))/1024/1024 AS Mbytes_max,
--             tablespace_name || ' (t) ' AS tablespace_name
             tablespace_name 
      FROM   sys.dba_temp_files
      GROUP BY tablespace_name )b
      WHERE a.tablespace_name (+) = b.tablespace_name
      and   t.tablespace_name (+) = b.tablespace_name
      and   b.tablespace_name like UPPER(DECODE('&PARAM1', '', '%', '&PARAM1'))
      ORDER BY tablespace)
LOOP
    IF c1.pct_used > v_percentage
    THEN
        v_grand_total_mb := v_grand_total_mb + c1.total_mb;
        v_grand_used_mb := v_grand_used_mb + c1.used_mb;
        v_grand_free_mb := v_grand_free_mb + c1.free_mb;

        DBMS_OUTPUT.PUT_LINE(RPAD(c1.tablespace || c1.contents,25) || 
                         TO_CHAR(c1.total_mb,'9,999,990') || ' ' || 
                         TO_CHAR(c1.used_mb,'9,999,990') || ' ' || 
                         TO_CHAR(c1.free_mb,'9,999,990') || ' ' || 
                         TO_CHAR(c1.pct_used,'990.99') || ' ' ||
                         c1.graph || ' ' || 
                         TO_CHAR(c1.Max_Size, '9,999,990') || ' ' ||
                         TO_CHAR(c1.pct_max_used, '990.99') || '  ' || 
                         c1.grapht);

        v_rec_count:= v_rec_count + 1;
    END IF;

END LOOP;
    -------------------------------------------------------
    -- Print a total line if you have more than one record
    -------------------------------------------------------
    IF (v_rec_count < 1)
    THEN
        DBMS_OUTPUT.PUT_LINE('Error: No tablespace details found  for tablespace: (' || NVL('&PARAM1','All') ||')!');
    END IF;
    IF (v_rec_count > 1)
    THEN
        DBMS_OUTPUT.PUT_LINE('------------------------ ---------- ---------- ----------');
        DBMS_OUTPUT.PUT_LINE('Total                   ' || TO_CHAR(v_grand_total_mb,'99,999,990') || TO_CHAR(v_grand_used_mb,'99,999,990') || TO_CHAR(v_grand_free_mb,'99,999,990'));
    END IF;
END;
/

SET FEEDBACK ON
UNDEFINE 1
UNDEFINE 2
UNDEFINE PARAM1
UNDEFINE PARAM2
