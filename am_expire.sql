set lines 120
set pages 1000
set feedback off
col expiry_info HEADING 'Account expiry for the AMCheck user(s)'

SELECT 'WARNING: The password for ' || username || ' expires on ' || TO_CHAR(expiry_date,'DD-MON-YY') as expiry_info
FROM   dba_users
WHERE  username IN ('AMO', 'AMU', 'AMR')
AND    NVL(expiry_date,sysdate + 365) < sysdate + 31
UNION ALL
SELECT 'The password for ' || username || ' expires on ' || NVL(TO_CHAR(expiry_date,'DD-MON-YY'),'** No Expiry Date Set **') as expiry_info
FROM   dba_users
WHERE  username IN ('AMO', 'AMU', 'AMR')
AND    NVL(expiry_date,sysdate + 365) >= sysdate + 31;
prompt
