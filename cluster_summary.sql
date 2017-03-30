-- Tony Webb 07th Nov 2016
--
-- 020 Changed to use a little pl/sql so we have a rowcount to test! 20 Feb 2017
--
-- N.B. Information may be incorrect or misleading. Use with caution!
--

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;
--

SET PAGES 1000
SET LINES 140
SET SERVEROUTPUT on
SET TAB OFF

COL physical_server_abbrev FORMAT a20 HEADING 'Server'
COL old_cluster FORMAT   a20 HEADING 'Expected Cluster'
COL new_cluster FORMAT   a20 HEADING 'Actual Cluster'
COL cluster_notes FORMAT a35 HEADING 'Notes'
COL cluster_name FORMAT  a20 HEADING 'Cluster Name'
COL instance_count           HEADING 'Instance Count'
COL physical_server_abbrev FORMAT a20 HEADING 'Server'

prompt ===============
prompt Cluster Report
prompt ===============

prompt
prompt Servers not running on the expected cluster (e.g. VMWare)
prompt ===========================================================

DECLARE
    v_rowcount          PLS_INTEGER:=0;
BEGIN
    FOR c1 IN (           
        SELECT m.physical_server_abbrev, m.cluster_name AS old_cluster, z.cluster_name AS new_cluster, 'WARNING: Known Oracle Cluster' as cluster_notes
        FROM  amu.am_vmware_server z,
        (SELECT s.physical_server_abbrev,
                s.cluster_name
         FROM   am_server s
         WHERE  NOT EXISTS (SELECT 1 FROM  amu.am_vmware_server v
                            WHERE v.cluster_name    = s.cluster_name
                            AND   UPPER(v.virtual_machine) = UPPER(s.physical_server_abbrev))
        AND   s.cluster_name IS NOT NULL
        AND   s.disabled <> 'Y') m
        WHERE UPPER(z.virtual_machine)= m.physical_server_abbrev
        AND   m.cluster_name IN (select cluster_name from am_server WHERE cluster_name IS NOT NULL AND disabled <> 'Y')
        AND   z.cluster_name IN (select cluster_name from am_server WHERE cluster_name IS NOT NULL AND disabled <> 'Y')
        UNION ALL
        SELECT m.physical_server_abbrev, m.cluster_name, z.cluster_name, 'ERROR: Unknown Cluster!'
        FROM  amu.am_vmware_server z,
              (SELECT s.physical_server_abbrev,
                      s.cluster_name
               FROM   am_server s
               WHERE  NOT EXISTS (SELECT 1 FROM  amu.am_vmware_server v
                                  WHERE v.cluster_name    = s.cluster_name
                                  AND   UPPER(v.virtual_machine) = UPPER(s.physical_server_abbrev))
               AND   s.cluster_name IS NOT NULL
               AND   s.disabled <>'Y') m
        WHERE UPPER(z.virtual_machine)= m.physical_server_abbrev
        AND   (m.cluster_name NOT IN (SELECT cluster_name FROM am_server WHERE cluster_name IS NOT NULL AND disabled <> 'Y')
        OR     z.cluster_name NOT IN (SELECT cluster_name FROM am_server WHERE cluster_name IS NOT NULL AND disabled <> 'Y')))
    LOOP
        DBMS_OUTPUT.PUT_LINE('Server ' ||c1.physical_server_abbrev || ' ' || RPAD(c1.old_cluster || ' (expected) ',42) || RPAD(c1.new_cluster || ' (actual) ',42) || c1.cluster_notes);
        v_rowcount := v_rowcount + 1;
    END LOOP;
    IF (v_rowcount < 1)
    THEN
        DBMS_OUTPUT.PUT_LINE('Hoorah! No nasty license surprises detected!');
    END IF;
    DBMS_OUTPUT.PUT_LINE (CHR(09));
END;
/

PROMPT
PROMPT Known Clusters 
PROMPT ===============

SET LINES 120
SET PAGES 1000
COL cluster_name   FORMAT A30 HEADING "Cluster"
COL server_count   FORMAT 990 HEADING "Server Count"
COL instance_count FORMAT 990 HEADING "Instance Count"

SELECT cluster_name, 
       COUNT(distinct physical_server_abbrev) AS server_count, 
       SUM(instance_count) AS instance_count
FROM   (SELECT NVL(s.cluster_name,'(No cluster)') AS cluster_name, s.physical_server_abbrev, d.instance_count 
        FROM   (SELECT server, count(*) AS instance_count FROM am_database WHERE disabled <> 'Y' GROUP BY server) d,
               am_server s
       WHERE  s.server = d.server (+)
       AND    s.disabled <> 'Y')
GROUP BY cluster_name
ORDER BY 1,2,3;

PROMPT
PROMPT EXPECTED Physical Servers/Cluster Mapping 
PROMPT ===========================================

COL cluster_name FORMAT a20
COL servers FORMAT a90 WORD_WRAP HEADING "Servers"

WITH no_dupes AS (SELECT DISTINCT physical_server_abbrev, cluster_name FROM am_server WHERE disabled <>'Y')
SELECT cluster_name, LISTAGG(physical_server_abbrev, ', ') WITHIN GROUP (ORDER BY physical_server_abbrev) AS servers
FROM no_dupes
WHERE cluster_name IS NOT NULL
GROUP BY cluster_name
UNION ALL
SELECT '(No Cluster)', LISTAGG(physical_server_abbrev, ', ') WITHIN GROUP (ORDER BY physical_server_abbrev) AS servers
FROM no_dupes
WHERE cluster_name IS NULL
GROUP BY cluster_name
ORDER BY cluster_name;

PROMPT
PROMPT The following servers may need to be disabled or removed (no enabled databases)
PROMPT ================================================================================
SET PAGES 0

SELECT server 
FROM   am_server  
WHERE  disabled <> 'Y' 
AND    server NOT IN (SELECT server FROM am_database WHERE disabled <> 'Y')
MINUS 
SELECT server 
FROM   am_server 
WHERE  physical_server_abbrev != server;

PROMPT
PROMPT N.B. The above may also include physical servers that are accessed via aliases. You probably want to leave those.
PROMPT
PROMPT

-- SELECT cluster_name, LISTAGG(physical_server_abbrev, ', ') WITHIN GROUP (ORDER BY physical_server_abbrev) AS servers
-- FROM am_server
-- WHERE cluster_name IS NOT NULL
-- GROUP BY cluster_name
-- UNION ALL
-- SELECT '(No Cluster)', LISTAGG(physical_server_abbrev, ', ') WITHIN GROUP (ORDER BY physical_server_abbrev) AS servers
-- FROM am_server
-- WHERE cluster_name IS NULL
-- GROUP BY cluster_name
-- ORDER BY cluster_name
-- /

