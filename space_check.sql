--
-- Author: Tony Webb March 2015
-- Changed April 2015 to work with new script.
-- Changed December 2015 to exclude UNDO and TEMP tablespaces.
--
WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

SET PAGES 1000
SET HEADING off
SET FEEDBACK off
SET LINES 200
SET SERVEROUTPUT on
SET TAB off

DECLARE
    TYPE t_tablespace IS TABLE OF VARCHAR2(200) INDEX BY PLS_INTEGER;
    v_database       v$database.name%TYPE:=SYS_CONTEXT('USERENV','DB_NAME');
    v_output         VARCHAR2(2000):=NULL;
    v_tablespace     t_tablespace;
BEGIN

    SELECT DISTINCT tablespace 
    BULK COLLECT INTO v_tablespace
    FROM (SELECT tablespace || '(' || pct_max_used || '%)' AS tablespace
          FROM
               (SELECT NVL(b.tablespace_name, NVL(a.tablespace_name,'UNKOWN')) AS tablespace,
                      ROUND((mbytes_alloc-NVL(mbytes_free,0))/NVL(mbytes_max,mbytes_alloc)*100) AS pct_max_used
                FROM (SELECT SUM(bytes)/1024/1024 AS Mbytes_free,
                             MAX(bytes)/1024/1024 AS mb_largest,
                             tablespace_name
                      FROM   sys.dba_free_space
                      GROUP BY tablespace_name ) a,
                     (SELECT SUM(bytes)/1024/1024    AS Mbytes_alloc,
                             SUM(GREATEST(maxbytes,bytes))/1024/1024 AS Mbytes_max,
                             tablespace_name
                      FROM   sys.dba_data_files
--                      GROUP BY tablespace_name
--                      UNION ALL
--                      SELECT SUM(bytes)/1024/1024    AS Mbytes_alloc,
--                             SUM(GREATEST(maxbytes,bytes))/1024/1024 AS Mbytes_max,
--                             tablespace_name
--                      FROM   sys.dba_temp_files
                      GROUP BY tablespace_name )b,
                 dba_tablespaces t
                 WHERE a.tablespace_name (+) = b.tablespace_name
                 and   t.contents NOT IN ('UNDO', 'TEMPORARY')
                 and   t.tablespace_name = b.tablespace_name
                 ORDER BY tablespace)
         WHERE pct_max_used > 89)
         ORDER BY  tablespace ASC;

    FOR i IN 1 .. v_tablespace.COUNT
    LOOP
       IF (i > 1)
       THEN
           v_output:=v_output || '; ';
       END IF;
       v_output:=v_output || v_tablespace(i);
    END LOOP;

    IF (v_output IS NULL)
    THEN
        DBMS_OUTPUT.PUT_LINE('** No tablespace alerts for ' || v_database || ' **');
    ELSE
        DBMS_OUTPUT.PUT_LINE('** ERROR - tablespace alerts on ' || v_database || ': ' || v_output || ' **');
    END IF;
END;
/

