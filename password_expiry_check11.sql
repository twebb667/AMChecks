-- Checks for any logins about to expire.
-- Also highlights non-system users where passwords haven't changed for over 1 year!

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
        DBMS_OUTPUT.PUT_LINE('** No Expired or Soon To Be expired Passwords Found **');
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

    SELECT COUNT(*)
    INTO   v_count
    FROM   sys.user$
    WHERE  ptime IS NOT NULL
    AND    ptime < sysdate -365
    AND    name not like 'APEX%'
    AND    name <> 'AMU'
    AND    name <> 'PERFSTAT'
    AND    name <> 'OWBSYS_AUDIT'
    AND    name NOT IN (SELECT user_name FROM sys.default_pwd$);

    IF (v_count < 1) OR (v_count IS NULL)
    THEN
        DBMS_OUTPUT.PUT_LINE('** No Overdue password changes detected **');
    ELSE
        FOR c1 IN (SELECT name, 
                          TO_CHAR(ptime,'DD FMMONTH YYYY') AS password_last_changed,
                          TRIM(TO_CHAR(sysdate - ptime,'999,999,990')) AS days_ago
                   FROM   sys.user$
                   WHERE  ptime IS NOT NULL
                   AND    ptime < sysdate -365
                   AND    name not like 'APEX%'
                   AND    name <> 'AMU'
                   AND    name <> 'PERFSTAT'
                   AND    name <> 'OWBSYS_AUDIT'
                   AND    name NOT IN (SELECT user_name FROM sys.default_pwd$))
        LOOP
            DBMS_OUTPUT.PUT_LINE('** WARNING ** ' || c1.name || ' password was last changed on ' || c1.password_last_changed || ' (' || c1.days_ago || ' days ago)');
        END LOOP;

    END IF;
END;
/

