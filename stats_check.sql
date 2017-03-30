
--
-- Lovingly crafted by Tony Webb 13th October 2014
--
-- pre oracle 10 code added by Tony Webb 17 November 2015
-- A warning is reported if non-SYS tables are found with locked stats
--

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

prompt

SET HEADING OFF
SET FEEDBACK OFF
SET LINES 200
SET SERVEROUTPUT ON
SET TAB off

DECLARE
  v_count          PLS_INTEGER:=0;
  v_database       v$database.name%TYPE;
  v_status         VARCHAR2(200);
  v_major_version  NUMBER(2);

BEGIN

  SELECT TO_NUMBER(SUBSTR(v.version,0,INSTR(v.version,'.')-1)),
         d.NAME 
  INTO v_major_version,
       v_database
  FROM v$instance v,
       v$database d;

  IF (v_major_version < 10)
  THEN
      v_status:='** Pre-Oracle 10 Database. Locked table stats not checked. **';
  ELSE
      -- start stats_check_10.sql
      SELECT COUNT(*) 
      INTO   v_count 
      FROM   dba_tab_statistics
      WHERE  stattype_locked IS NOT NULL
      AND    owner NOT LIKE '%SYS%';

      IF (v_count > 0)
      THEN
        v_status:='** WARNING on ' || v_database || ':- ' || TO_CHAR(v_count) || ' non SYS-type tables with locked stats found. **';
      ELSE
        v_status:='** No non SYS-type tables with locked stats found. **';
      END IF;
  END IF;
         
  DBMS_OUTPUT.PUT_LINE(v_status);

END;
/
