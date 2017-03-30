
--
-- Author: Tony Webb 21st Dec 2016
--
--
SET PAGES 1000
SET FEEDBACK OFF
SET SERVEROUTPUT ON
SET LINES 6000
COL SESSION_DETS HEADING "User Sessions" FORMAT A150

DECLARE

    TYPE t_kill IS RECORD (text   VARCHAR2(200),
                           sid    v$session.sid%TYPE);

    TYPE t_sessions IS RECORD (session_status VARCHAR2(200),
                               sid            v$session.sid%TYPE,
                               rownum         PLS_INTEGER:=0);

    TYPE t_sql IS RECORD (sid        v$session.sid%TYPE,
                          serial#    v$session.serial#%TYPE,
                          username   v$session.username%TYPE,
                          program    v$session.program%TYPE,
                          sql_id     VARCHAR2(400), 
		          spid       v$process.spid%TYPE,
                          sql_text   VARCHAR2(2000));

    TYPE t_killdet    IS TABLE OF t_kill;
    TYPE t_sessiondet IS TABLE OF t_sessions;
    TYPE t_sqldet     IS TABLE OF t_sql;

    v_killdet         t_killdet;
    v_sessiondet      t_sessiondet;
    v_sqldet          t_sqldet;

    v_rowcount        PLS_INTEGER:=0;
    v_version         PLS_INTEGER:=0;
    v_sql             VARCHAR2(2000):=NULL;

BEGIN

    SELECT DISTINCT s1.username || ' (' || s1.osuser || ') on ' || NVL(SUBSTR(s1.machine,1,INSTR(s1.machine, '.')-1),s1.machine)
        || ' (SID=' || s1.sid || ' SERIAL#=' || s1.serial# || ' [OSPID:' || p1.spid || ']) using: ' || NVL(SUBSTR(s1.program,1, INSTR(s1.program, '.')-1),s1.program) 
        || ' since ' || TO_CHAR(s1.logon_time,'DD Mon YYYY hh24:mi:ss') || ' (last call: ' || TO_CHAR(ROUND(s1.last_call_et/60)) || ' mins ago)' AS session_status,
        s1.sid,
        ROWNUM
    BULK COLLECT INTO v_sessiondet
    FROM v$session s1,
         v$process p1
    WHERE  s1.paddr = p1.addr
    AND s1.username IS NOT NULL
    AND s1.type != 'BACKGROUND'
    ORDER BY sid;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '~~~~~~~~~~~~~~~~~');
    DBMS_OUTPUT.PUT_LINE('Session Summary' || CHR(10) || '~~~~~~~~~~~~~~~~~' || CHR(10));
    FOR i IN 1 .. v_sessiondet.COUNT
    LOOP
        DBMS_OUTPUT.PUT_LINE(v_sessiondet(i).session_status);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    DBMS_OUTPUT.PUT_LINE('SQL (for those sessions where we can see it!)' || CHR(10) || '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' || CHR(10));

    DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------------------------------------------------------------------------' || CHR(10)||
                         'SID    SERIAL# USERNAME                       PROGRAM                                       SQL_ID               SPID' || CHR(10) ||
                         '-----------------------------------------------------------------------------------------------------------------------------------');

    SELECT /*+ RULE */ DISTINCT x.sid, x.serial#, x.username, x.program, DECODE(x.sql_id,NULL,x.prev_sql_id || '(prev)',x.sql_id) AS sql_id, p.spid, y.sql_text || ' (previous SQL) ' AS sql_text
    BULK COLLECT INTO v_sqldet
    FROM   v$session x, v$sql y, v$process p
    WHERE  x.paddr = p.addr
    AND    x.type != 'BACKGROUND'
    AND    (x.sql_id IS NOT NULL or x.prev_sql_id IS NOT NULL)
    AND    DECODE(x.sql_id,null,x.prev_sql_id,x.sql_id) = y.sql_id (+)
    ORDER BY sid;

    FOR i IN 1 .. v_sqldet.COUNT
    LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(TO_CHAR(v_sqldet(i).sid),7) || 
                             RPAD(TO_CHAR(v_sqldet(i).serial#),8) || 
                             RPAD(v_sqldet(i).username,31) ||
                             RPAD(v_sqldet(i).program,45) || ' ' ||
                             RPAD(TO_CHAR(v_sqldet(i).sql_id),21) ||
                             RPAD(v_sqldet(i).spid,12));

        IF (v_sqldet(i).sql_text IS NOT NULL)
        THEN
            DBMS_OUTPUT.PUT_LINE('SQL:   ' || REGEXP_REPLACE(v_sqldet(i).sql_text, '(.{120})', '\1' || CHR(10) ));
            DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------------------------------------------------------------------------' || CHR(10));
        END IF;

   END LOOP;

    DBMS_OUTPUT.PUT_LINE('Use "ALTER SYSTEM KILL SESSION ' || '''' || 'sid,serial#' || ''''  || ' IMMEDIATE;" in sqlplus to kill the blocking sessions, e.g. ');
    DBMS_OUTPUT.PUT_LINE(CHR(10));

    SELECT DISTINCT 'ALTER SYSTEM KILL SESSION  ' || '''' || RPAD(s1.sid || ',' || s1.serial# || '''',10) || ' IMMEDIATE;' AS text, s1.sid
    BULK COLLECT INTO v_killdet
    FROM v$session s1,
         v$process p1
    WHERE s1.paddr = p1.addr
    AND s1.username IS NOT NULL
    AND s1.type != 'BACKGROUND'
    ORDER BY sid;

    FOR i IN 1 .. v_killdet.COUNT
    LOOP
        DBMS_OUTPUT.PUT_LINE(CHR(09) || v_killdet(i).text);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(CHR(10));
END;
/

