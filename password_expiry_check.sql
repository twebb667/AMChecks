-- Checks for any logins about to expire.

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
    v_days_old       NUMBER:=31;
    v_expirestring   VARCHAR2(8);
    v_userstring     VARCHAR2(5):='users';

--    TYPE t_userst    IS TABLE OF dba_users%ROWTYPE INDEX BY PLS_INTEGER;
    TYPE t_usersty IS RECORD (username       dba_users.username%TYPE,
                              expiry_date    dba_users.expiry_date%TYPE,
                              profile        dba_users.profile%TYPE,
                              account_status dba_users.account_status%TYPE);

    TYPE t_userst    IS TABLE OF t_usersty;
    v_users          t_userst;

BEGIN

    SELECT COUNT(*)
    INTO   v_count
    FROM   dba_users
    WHERE  ((account_status = 'OPEN' ) AND expiry_date IS NOT NULL AND (expiry_date < (sysdate + v_days_old)))
    OR    (account_status = 'EXPIRED')
    OR    (account_status = 'EXPIRED(GRACE)');

    IF (v_count < 1) OR (v_count IS NULL)
    THEN
        DBMS_OUTPUT.PUT_LINE('** No Password Expiry Issues Found **');
    ELSE
        IF (v_count = 1)
        THEN
            v_userstring := 'user';
        ELSE
            v_userstring := 'users';
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('** WARNING - ' || TO_CHAR(v_count) || ' ' || v_userstring || ' found with Password Expiry Issues **');
        SELECT username,
               expiry_date, 
               profile,
               account_status
        BULK COLLECT INTO v_users
        FROM   dba_users
        WHERE  ((account_status = 'OPEN' ) AND expiry_date IS NOT NULL AND (expiry_date < (sysdate + v_days_old)))
        OR    (account_status = 'EXPIRED')
        OR    (account_status = 'EXPIRED(GRACE)');
    
        FOR i IN 1 .. v_users.COUNT
        LOOP
              IF (v_users(i).expiry_date < sysdate)
              THEN
                  v_expirestring := 'expired';
              ELSE
                  v_expirestring := 'expires';
              END IF;
            DBMS_OUTPUT.PUT_LINE('**   Password for user ' || TRIM(v_users(i).username) || ' ' || v_expirestring || ' on ' || TRIM(TO_CHAR(v_users(i).expiry_date,'Dd-Mon-YYYY'))  ||  ' Profile: ' || TRIM(v_users(i).profile) || ' (' || TRIM(v_users(i).account_status) || ') **');
        END LOOP;

    END IF;

END;

/

