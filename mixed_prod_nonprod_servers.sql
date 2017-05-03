--
-- Noddy report showing servers that have a mix of production and non-production databases on them
--
-- Tony Webb 03 May 2017
--

SET LINES 120
SET PAGES 1000
COL database_name HEADING "DB"
COL physical_server_abbrev FORMAT a20 HEADING "SERVER"
COL production_ind FORMAT a6 HEADING "PROD?"
BREAK ON physical_server_abbrev SKIP 1

SELECT s.physical_server_abbrev,
       d.database_name,
       d.production_ind
FROM   amo.am_database d,
       amo.am_server s
WHERE  d.server = s.server
AND    d.disabled <> 'Y'
AND    s.disabled <> 'Y'
AND    EXISTS (SELECT 1
               FROM   amo.am_database d2,
                      amo.am_server s2
               WHERE  s2.server = d2.server
               AND    d2.disabled <> 'Y'
               AND    s2.disabled <> 'Y'
               AND    s.physical_server_abbrev = s2.physical_server_abbrev
               AND    d.database_name <> d2.database_name
               AND    d.production_ind <> d2.production_ind)
ORDER BY s.physical_server_abbrev,
         d.database_name,
         d.production_ind
/

