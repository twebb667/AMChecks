SET LINES 140
SET PAGES 1000
COL created HEADING "Created within the last 31 days"

prompt

SELECT RPAD(o.owner || '.' || o.object_name || ' (' || o.object_type || ')',50) || ' Created on ' ||  TO_CHAR(o.created,'DD-Mon-YY HH12:MI:SS pm') AS created
FROM  dba_objects o,
      v$database d
WHERE o.created > d.created +1
AND   o.created > sysdate -32
AND   o.object_name NOT LIKE 'WRH$_FILESTATXS%'
AND   o.object_name NOT LIKE '"BIN "%'
AND   o.object_type NOT LIKE '%PARTITION%'
AND NOT EXISTS (SELECT 1 FROM dba_recyclebin b where b.object_name = o.object_name)
ORDER by o.created ASC
/
prompt Objects in the recyclebin by owner
select owner, count(*) recyclebin_objects from dba_recyclebin group by owner order by 2 desc;
prompt

