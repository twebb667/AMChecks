-- Need to determine if there is an external table, dfspace, created and populated.
-- If it is too old then consider it an error!

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;
SET PAGES 1000
SET HEADING off
SET FEEDBACK off
SET LINES 200
SET SERVEROUTPUT on
SET TAB OFF

DECLARE
    v_count          PLS_INTEGER;
    v_output         VARCHAR2(2000):=NULL;
    v_days_old       NUMBER;
    v_sql            VARCHAR2(2000):=NULL;

    table_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(table_not_found, -942);

BEGIN

    SELECT COUNT(*) 
    INTO  v_count
    FROM  all_external_tables
    WHERE owner = 'AMO'
    AND   table_name = 'DFSPACE';

    IF (v_count < 1) OR (v_count IS NULL)
    THEN
        DBMS_OUTPUT.PUT_LINE('REGULAR:0');
    ELSE
        v_sql := 'SELECT ROUND(sysdate - TO_DATE(MAX(space_chartime),' ||
                 '''' || 'DD/MM/YY-HH24' || ':mi:ss' || '''' || ') ) FROM   amo.dfspace';
        -- DBMS_OUTPUT.PUT_LINE(v_sql);
        EXECUTE IMMEDIATE v_sql 
        INTO   v_days_old;

        IF (v_days_old > 1 )
        THEN
            DBMS_OUTPUT.PUT_LINE('WARNING:' || v_days_old);
        ELSE
            DBMS_OUTPUT.PUT_LINE('DFSPACE:' || v_days_old);
        END IF;
    END IF;

EXCEPTION
WHEN table_not_found
THEN
    DBMS_OUTPUT.PUT_LINE('NOT_OK: Table NOT FOUND!');
END;
/
EXIT;

