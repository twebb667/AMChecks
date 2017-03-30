
-- Courtesy of Pythian group
-- pl/sqlized and other minor changes - A M Webb 06 May 2015
-- parameterised by A M Webb 09th Feb 2016

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

SET LINES 220
SET SERVEROUTPUT ON 
SET TAB OFF
SET PAGES 1000
SET FEEDBACK OFF

SET VERIFY OFF
SET TERMOUT OFF
COLUMN 1 new_value 1
SELECT ''  AS "1" FROM dual WHERE ROWNUM = 0;
DEFINE PARAM1 = '&1'
SET TERMOUT ON
SET SERVEROUTPUT ON

DECLARE
    v_age            PLS_INTEGER;
    v_database       v$database.name%TYPE:=SYS_CONTEXT('USERENV','DB_NAME');
    v_environment    VARCHAR2(8):=NULL;
BEGIN

-- Maybe derive v_age from server name, instance name or another table?
-- Currently it is an optional positional parameter.

    v_age := NVL('&PARAM1',7);

    IF (v_age = 1)
    THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Backup results for the last day');
    ELSE
        DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Backup results for the last ' || v_age || ' days');
    END IF;

    DBMS_OUTPUT.PUT_LINE('==============================================' || CHR(10));
    DBMS_OUTPUT.PUT_LINE('When                                                Output                             Elapsed     Time                                       Output');
    DBMS_OUTPUT.PUT_LINE('Ran                                                 MBytes  Status     Type            Seconds     Taken    Ctrl   Full    DF0    DF1   Logs   Inst');
    DBMS_OUTPUT.PUT_LINE('--------- -------------------------------------- ---------- ---------- ------------- ---------- ---------- ------ ------ ------ ------ ------ ------');

    FOR rman_rec IN
      (SELECT /*+ rule */
      RPAD(TO_CHAR(j.start_time, 'Day'),10) ||
      RPAD(TO_CHAR(j.start_time, 'dd Mon yyyy (hh24:mi:ss)'),24) || ' => ' || 
      RPAD(TO_CHAR(j.end_time, '(hh24:mi:ss)'),10) ||  ' ' ||
      LPAD(TO_CHAR(TO_NUMBER(ROUND(j.output_bytes/1024/1024)),'9,999,990'),10) || ' ' ||
      RPAD(DECODE(j.status,'COMPLETED WITH ERRORS','ERRORS','COMPLETED WITH WARNINGS', 'WARNINGS', status),11) ||
      RPAD(j.input_type,12) || 
      LPAD(TO_CHAR(TO_NUMBER(ROUND(j.elapsed_seconds)),'999,999,990'),12) ||  ' ' ||
      LPAD(j.time_taken_display,10) ||
      TO_CHAR(x.cf, '99,990') ||
      TO_CHAR(x.df, '99,990') ||
      TO_CHAR(x.i0, '99,990') ||
      TO_CHAR(x.i1, '99,990') ||
      TO_CHAR(x.l, '99,990') ||
      TO_CHAR(ro.inst_id, '999999') 
AS output
    FROM V$RMAN_BACKUP_JOB_DETAILS j
      LEFT OUTER JOIN (SELECT /*+ rule */
                     d.session_recid, d.session_stamp,
                     SUM(CASE WHEN d.controlfile_included = 'YES' THEN d.pieces ELSE 0 END) CF,
                     SUM(CASE WHEN d.controlfile_included = 'NO'
                               AND d.backup_type||d.incremental_level = 'D' THEN d.pieces ELSE 0 END) DF,
                     SUM(CASE WHEN d.backup_type||d.incremental_level = 'D0' THEN d.pieces ELSE 0 END) I0,
                     SUM(CASE WHEN d.backup_type||d.incremental_level = 'I1' THEN d.pieces ELSE 0 END) I1,
                     SUM(CASE WHEN d.backup_type = 'L' THEN d.pieces ELSE 0 END) L
                   FROM
                     V$BACKUP_SET_DETAILS d
                     JOIN V$BACKUP_SET s ON s.set_stamp = d.set_stamp AND s.set_count = d.set_count
                   WHERE s.input_file_scan_only = 'NO'
                   GROUP BY d.session_recid, d.session_stamp) x
        ON x.session_recid = j.session_recid AND x.session_stamp = j.session_stamp
      LEFT OUTER JOIN (SELECT /*+ rule */ o.session_recid, o.session_stamp, MIN(inst_id) inst_id
                       FROM GV$RMAN_OUTPUT o
                       GROUP BY o.session_recid, o.session_stamp)
        ro ON ro.session_recid = j.session_recid AND ro.session_stamp = j.session_stamp
    WHERE j.start_time > trunc(sysdate)-v_age
    ORDER BY j.start_time)
    LOOP
        DBMS_OUTPUT.PUT_LINE(rman_rec.output);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'KEY: Ctrl - Controlfiles; Full - Full backups; DF0 - Datafile level 0 backups; DF1 - Datafile level 1 backups; Logs - Archivelogs; Output|Inst - Output instance' || CHR(10));
END;
/

CLEAR COLUMNS
