
--
-- Author: Tony Webb 16th Nov 2016
--
--

SET FEEDBACK OFF
SET SERVEROUTPUT ON
SET LINES 400

DECLARE

    TYPE t_locking IS RECORD (blocking_status VARCHAR2(600), 
                              sid             v$session.sid%TYPE,
			      blocked_mins    PLS_INTEGER:=0,
                              rownum          PLS_INTEGER:=0);

    TYPE t_lockdet IS TABLE OF t_locking;

    TYPE t_session IS RECORD (sid        v$session.sid%TYPE,
                              serial#    v$session.serial#%TYPE,
                              username   v$session.username%TYPE,
                              program    v$session.program%TYPE,
                              sql_id     VARCHAR2(20), 
			      spid       v$process.spid%TYPE,
                              sql_text   v$sql.sql_text%TYPE);

    TYPE t_sessiondet IS TABLE OF t_session;

    TYPE t_kill IS RECORD (text VARCHAR2(200));

    TYPE t_killdet IS TABLE OF t_kill;

    v_locks             t_lockdet;
    v_lockdetails       t_lockdet;
    v_sessiondet        t_sessiondet;
    v_killdet           t_killdet;

    v_blockers          VARCHAR2(2000);
    v_blocked_mins      PLS_INTEGER:=0;
    v_rowcount          PLS_INTEGER:=0;
    v_version           PLS_INTEGER:=0;
    v_send_mail         CHAR(1):='N';
    v_sql               VARCHAR2(2000):=NULL;

BEGIN

    SELECT DISTINCT TO_NUMBER(SUBSTR(version,0,INSTR(version,'.',1,2)-1))*10
    INTO   v_version
    FROM   dba_registry
    WHERE  comp_name LIKE 'Ora%Catalog Views';

    IF (v_version > 111)
    THEN
        --
        -- Dynamic SQL to avoid syntax errors on older database versions
        --
        v_sql := 'SELECT LISTAGG(holding_session, ' || '''' || CHR(44) || '''' || ') WITHIN GROUP (ORDER BY holding_session) AS dba_blockers FROM dba_blockers';
        EXECUTE IMMEDIATE v_sql
        INTO   v_blockers;
    END IF;
        
    SELECT DISTINCT 'ALTER SYSTEM KILL SESSION ' || '''' || s1.sid || ',' || s1.serial# || '''' || ' IMMEDIATE;' AS text
    BULK COLLECT INTO v_killdet
    FROM v$lock l1,
         v$session s1,
         v$process p1
    WHERE s1.sid=l1.sid
    AND s1.paddr = p1.addr
    AND l1.BLOCK=1
    AND s1.type != 'BACKGROUND';

    SELECT DISTINCT '-- BLOCKER => ' || s1.username || ' (' || s1.osuser || ') on ' || NVL(SUBSTR(s1.machine,1,INSTR(s1.machine, '.')-1),s1.machine)
        || ' (SID=' || s1.sid || ' SERIAL#=' || s1.serial# || ' [OSPID:' || p1.spid || ']) using: ' || NVL(SUBSTR(s1.program,1, INSTR(s1.program, '.')-1),s1.program) 
        || ' since ' || TO_CHAR(s1.logon_time,'DD Mon YYYY hh24:mi:ss') || ' (last call: ' || TO_CHAR(ROUND(s1.last_call_et/60)) || ' mins ago)' AS blocking_status, 
        s1.sid,
        s1.last_call_et/60 AS blocked_mins,
        ROWNUM
    BULK COLLECT INTO v_locks
    FROM v$lock l1,
         v$session s1,
         v$process p1
    WHERE s1.sid=l1.sid 
    AND s1.paddr = p1.addr
    AND l1.BLOCK=1 
    AND s1.type != 'BACKGROUND';

    FOR i IN 1 .. v_locks.COUNT
    LOOP
       IF (v_locks(i).rownum = 1)
        THEN
            DBMS_OUTPUT.PUT_LINE(CHR(10) || '~~~~~~~~~~~~~~~');
            DBMS_OUTPUT.PUT_LINE('Lock Summary' || CHR(10) || '~~~~~~~~~~~~~~~' || CHR(10));
            IF (v_blockers IS NOT NULL)
            THEN
                DBMS_OUTPUT.PUT_LINE('SIDs in dba_blockers: ' || v_blockers || CHR(10));
            END IF;
        END IF;
        DBMS_OUTPUT.PUT_LINE(v_locks(i).blocking_status);

        SELECT /*+ RULE */ '---- BLOCKED => ' || s2.username || ' (' || s2.osuser || ') on ' || NVL(SUBSTR(s2.machine,1, INSTR(s2.machine, '.')-1),s2.machine)
               || ' (SID=' || s2.sid || ') using: ' || NVL(SUBSTR(s2.program,1, INSTR(s2.program, '.')-1),s2.program) || ' since ' 
               || TO_CHAR(s2.logon_time,'DD Mon YYYY hh24:mi:ss') || ' (last call: ' || TO_CHAR(ROUND(s2.last_call_et/60)) || ' mins ago)' AS blocking_status, 
               s2.sid,
               s2.last_call_et/60 AS blocked_mins,
               ROWNUM
        BULK COLLECT INTO v_lockdetails
        FROM v$lock l1,
             v$session s1,
             v$lock l2,
             v$session s2
        WHERE s1.sid=l1.sid AND s2.sid=l2.sid
        AND l1.BLOCK=1 AND l2.request > 0
        AND l1.id1 = l2.id1
        AND l1.id2 = l2.id2
        AND s1.type != 'BACKGROUND'
        AND s1.sid = v_locks(i).sid;

        FOR i IN 1 .. v_lockdetails.COUNT
        LOOP
            DBMS_OUTPUT.PUT_LINE(v_lockdetails(i).blocking_status);
            IF (v_lockdetails(i).blocked_mins > v_blocked_mins)
            THEN
                v_blocked_mins := v_lockdetails(i).blocked_mins;
            END IF ;
        END LOOP;
    END LOOP;

    v_rowcount := SQL%ROWCOUNT;
    IF (v_rowcount > 0 )
    THEN
        v_send_mail := 'Y';
    END IF;

    IF (v_send_mail = 'Y')
    THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Blockers - Session Details');
        DBMS_OUTPUT.PUT_LINE('~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
        DBMS_OUTPUT.PUT_LINE(CHR(10) || 'SID    SERIAL# USERNAME                       PROGRAM                                       SQL_ID               OSPID');
        DBMS_OUTPUT.PUT_LINE('------ ------- ------------------------------ --------------------------------------------- -------------------- ----------');

	SELECT /*+ RULE */ DISTINCT x.sid, x.serial#, x.username, x.program, DECODE(x.sql_id,NULL,x.prev_sql_id || '(prev)',x.sql_id) AS sql_id, p.spid, y.sql_text || ' (previous SQL) ' AS sql_text
        BULK COLLECT INTO v_sessiondet
	FROM   v$session x, v$sql y, v$process p
	WHERE  x.sid IN
       	       (SELECT a.sid
                FROM   v$lock a, 
                       v$lock b
                WHERE  1=1
                AND    a.block = 1
                AND    b.request > 0
                AND    a.id1 = b.id1
                AND    a.id2 = b.id2)
		AND    x.paddr = p.addr
                AND    x.type != 'BACKGROUND'
                AND    DECODE(x.sql_id,null,x.prev_sql_id,x.sql_id) = y.sql_id (+);
--                AND    x.sql_child_number = y.child_number (+);

        FOR i IN 1 .. v_sessiondet.COUNT
        LOOP
            DBMS_OUTPUT.PUT_LINE(RPAD(TO_CHAR(v_sessiondet(i).sid),7) || 
                                 RPAD(TO_CHAR(v_sessiondet(i).serial#),8) || 
                                 RPAD(v_sessiondet(i).username,31) ||
                                 RPAD(v_sessiondet(i).program,45) || ' ' ||
                                 RPAD(TO_CHAR(v_sessiondet(i).sql_id),21) ||
                                 RPAD(v_sessiondet(i).spid,12));

            IF (v_sessiondet(i).sql_text IS NOT NULL)
            THEN
                DBMS_OUTPUT.PUT_LINE('SQL:   ' || REGEXP_REPLACE(v_sessiondet(i).sql_text, '(.{120})', '\1' || CHR(10) ));
                DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------------------------' || CHR(10));
            END IF;

        END LOOP;

        DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Blocked - Session Details');
        DBMS_OUTPUT.PUT_LINE('~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
        DBMS_OUTPUT.PUT_LINE(CHR(10) || 'SID    SERIAL# USERNAME                       PROGRAM                                       SQL_ID');
        DBMS_OUTPUT.PUT_LINE('------ ------- ------------------------------ --------------------------------------------- -------------');

	SELECT /*+ RULE */ DISTINCT x.sid, x.serial#, x.username, x.program, x.sql_id, 0, y.sql_text
        BULK COLLECT INTO v_sessiondet
	FROM   v$session x, v$sql y
	WHERE  x.sid IN
       	       (SELECT a.sid
                FROM   v$lock a, 
                       v$lock b
                WHERE  1=1
                AND    a.block = 0
                AND    b.request > 0
                AND    a.id1 = b.id1
                AND    a.id2 = b.id2)
                AND    x.type != 'BACKGROUND'
                AND    x.sql_id = y.sql_id (+)
                AND    x.sql_child_number = y.child_number (+);

        FOR i IN 1 .. v_sessiondet.COUNT
        LOOP
            DBMS_OUTPUT.PUT_LINE(RPAD(TO_CHAR(v_sessiondet(i).sid),7) || 
                                 RPAD(TO_CHAR(v_sessiondet(i).serial#),8) || 
                                 RPAD(v_sessiondet(i).username,31) ||
                                 RPAD(v_sessiondet(i).program,45) || ' ' ||
                                 RPAD(TO_CHAR(v_sessiondet(i).sql_id),14));

            IF (v_sessiondet(i).sql_text IS NOT NULL)
            THEN
                DBMS_OUTPUT.PUT_LINE('SQL:   ' || REGEXP_REPLACE(v_sessiondet(i).sql_text, '(.{120})', '\1' || CHR(10) ));
            END IF;

        END LOOP;
        IF (v_sessiondet.COUNT > 0)
        THEN
            DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------------------------------------------------' || CHR(10));
        END IF;
        DBMS_OUTPUT.PUT_LINE('Use "ALTER SYSTEM KILL SESSION ' || '''' || 'sid,serial#' || ''''  || ' IMMEDIATE;" in sqlplus to kill the blocking sessions, e.g. ');
        DBMS_OUTPUT.PUT_LINE(CHR(10));
        FOR i IN 1 .. v_killdet.COUNT
        LOOP
            DBMS_OUTPUT.PUT_LINE(CHR(09) || v_killdet(i).text);
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(CHR(10));
        IF (v_blocked_mins > 30)
        THEN
            DBMS_OUTPUT.PUT_LINE('N.B. One or more sessions has been blocked for at least 30 minutes!');
            IF (v_blocked_mins > 60)
            THEN
                DBMS_OUTPUT.PUT_LINE('..... Actually its more than an hour now!');
                IF (v_blocked_mins > 120)
                THEN
                    DBMS_OUTPUT.PUT_LINE('..... make that more than 2 hours.');
                END IF;
            END IF;
        END IF;
    END IF;
END;
/

