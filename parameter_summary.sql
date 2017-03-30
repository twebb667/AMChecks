set lines 120
set pages 1000

SELECT name || ' => ' || value AS param
FROM v$parameter 
WHERE isdefault = 'FALSE' 
ORDER BY 1;

exit;

