set lines 120
set pages 1000

col metric format a40
col value format 999,999,999,990

SELECT 'WAIT: SINGLE BLOCK READ' AS metric, TO_CHAR(sum(decode(event,'db file sequential read',total_waits,0))) AS value
FROM V$system_event WHERE 1=1 AND event not in (
  'SQL*Net message FROM client',
  'SQL*Net more data FROM client',
  'pmon timer', 'rdbms ipc message',
  'rdbms ipc reply', 'smon timer')
UNION ALL
SELECT 'WAIT: SQLNET WAITS', TO_CHAR(sum(decode(event,'SQL*Net message to client',total_waits,'SQL*Net message to dblink',total_waits,
'SQL*Net more data to client',total_waits,'SQL*Net more data to dblink',total_waits,'SQL*Net break/reset to client',total_waits,
'SQL*Net break/reset to dblink',total_waits,0))) SQLNET 
FROM V$system_event WHERE event not in ( 'SQL*Net message FROM client','SQL*Net more data FROM client','pmon timer',
'rdbms ipc message','rdbms ipc reply', 'smon timer')
UNION ALL
SELECT 'WAIT: OTHER WAITS', TO_CHAR(sum(decode(event,'control file sequential read',0,'control file single write',0,'control file parallel write',0,'
db file sequential read',0,'db file scattered read',0,'direct path read',0,'file identify',0,'file open',0,'SQL*Net message to client',0,
'SQL*Net message to dblink',0, 'SQL*Net more data to client',0,'SQL*Net more data to dblink',0, 'SQL*Net break/reset to client',0,
'SQL*Net break/reset to dblink',0, 'log file single write',0,'log file parallel write',0,total_waits))) Other 
FROM V$system_event 
WHERE event not in ('SQL*Net message FROM client', 'SQL*Net more data FROM client', 'pmon timer', 'rdbms ipc message',  'rdbms ipc reply', 'smon timer')
UNION ALL
SELECT 'WAIT: MULTIBLOCK READ', TO_CHAR(sum(decode(event,'db file scattered read',total_waits,0))) MultiBlockRead
FROM V$system_event WHERE 1=1 AND event not in ('SQL*Net message FROM client','SQL*Net more data FROM client','pmon timer', 'rdbms ipc message', 'rdbms ipc reply', 
'smon timer')
UNION ALL
SELECT 'WAIT: LOGWRITE', TO_CHAR(sum(decode(event,'log file single write',total_waits, 'log file parallel write',total_waits,0))) LogWrite
FROM V$system_event WHERE 1=1 AND event not in ('SQL*Net message FROM client', 'SQL*Net more data FROM client', 'pmon timer', 'rdbms ipc message', 
'rdbms ipc reply', 'smon timer')
UNION ALL
SELECT 'WAIT: IO WAITS', TO_CHAR(sum(decode(event,'file identify',total_waits, 'file open',total_waits,0))) FileIO 
FROM V$system_event 
WHERE event not in ('SQL*Net message FROM client', 'SQL*Net more data FROM client', 'pmon timer', 'rdbms ipc message', 'rdbms ipc reply', 'smon timer')
UNION ALL
SELECT 'WAIT: CONTROLFILE IO ', TO_CHAR(sum(decode(event,'control file sequential read', total_waits,
'control file single write', total_waits, 'control file parallel write',total_waits,0))) ControlFileIO
FROM V$system_event WHERE 1=1 AND event not in ( 
  'SQL*Net message FROM client', 
  'SQL*Net more data FROM client', 
  'pmon timer', 'rdbms ipc message', 
  'rdbms ipc reply', 'smon timer')
UNION ALL
SELECT 'WAIT: DIRECTPATH READ', TO_CHAR(sum(decode(event,'direct path read',total_waits,0))) DirectPathRead 
FROM V$system_event 
WHERE event not in ('SQL*Net message FROM ', 'SQL*Net more data FROM client','pmon timer', 'rdbms ipc message', 'rdbms ipc reply', 'smon timer') 
UNION ALL
SELECT 'SESSIONS: HIGHWATER',  TO_CHAR(sessions_highwater)
FROM   v$license
UNION ALL
SELECT 'SESSIONS: CURRENT', TO_CHAR(count(username)) FROM v$session WHERE username IS NOT NULL
UNION ALL
SELECT 'STAT: ' || UPPER(name), TO_CHAR(value)
FROM V$SYSSTAT
WHERE name IN (
    'db block gets',
    'consistent gets',
    'physical reads',
    'physical reads direct',
    'physical writes direct',
    'table scans (direct read)',
    'table scans (long tables)',
    'table scans (rowid ranges)',
    'table scans (short tables)',
    'db_block_changes',
    'redo writes'
)
;

