
SET FEEDBACK OFF
SET SERVEROUTPUT ON
SET LINES 200

--prompt

DECLARE
    v_rowcount          PLS_INTEGER:=0;
    v_log_mode          v$database.log_mode%TYPE;

BEGIN
    SELECT   log_mode
    INTO     v_log_mode
    FROM     v$database;

--    DBMS_OUTPUT.PUT_LINE (v_log_mode || ' Mode' || CHR(10));

    IF (v_log_mode = 'ARCHIVELOG')
    THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Backup Type      Latest Backup');
        DBMS_OUTPUT.PUT_LINE('--------------   -----------------------------------');

        FOR c1 IN (
            SELECT DECODE(backup_type,'I','Incremental DB','D','DB','L','Archivelog') AS backup_type, 
            TO_CHAR(MAX(completion_time),'Day ddth Mon YYYY HH24:MI:SS PM') AS latest_backup
            FROM   v$backup_set 
            GROUP BY backup_type
            ORDER BY 1
        )
        LOOP
            DBMS_OUTPUT.PUT_LINE(RPAD(c1.backup_type,17) || c1.latest_backup);
            v_rowcount := v_rowcount + 1;
        END LOOP;
        IF (v_rowcount < 1)
        THEN
            DBMS_OUTPUT.PUT_LINE('WARNING: No detected backups but database is in archivelog mode..');
        END IF;
        DBMS_OUTPUT.PUT_LINE (CHR(09));
    END IF;   
END;
/

