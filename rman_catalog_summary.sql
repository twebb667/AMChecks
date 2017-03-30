WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

--
-- Script that runs on an RMAN catalog to report on all databases.
-- 
-- Author: Tony Webb 04 Jan 2016
--
-- Added server name 30 June 2016
--
-- Physical server changes 12/07/16
-- DBID work 09 Sept 2016
-- Directory listing changed 13 Sept 2016
-- Corrected bug (failed db backups) and added DBID to missing_backups
--
-- *) The assumption is that all backups are via the RMAN catalog. 
--
-- *) The rman details are exposed to amo in the amchecks database via several views which use a database link to the rman owner.
--    If there is more than one catalog then you'll need to add in some unions into the view definition or do some other jiggery pokery.
--
--    Current views include:
--    
--    RMAN_BACKUP_DIRECTORY
--    RMAN_DETAILS
--    RMAN_LAST_BACKUP
--    RMAN_MISSING_BACKUPS
--
-- *) Note that an optional parameter of database name can be supplied.
--
-- *) There is a rule hint (or 3) in the views' DDL code. ..Sorry but it seems to make a big difference even on a new catalog!
--

SET FEEDBACK OFF
SET LINES 200
SET PAGES 1000
SET SERVEROUTPUT on
SET TAB OFF
SET TRIMSPOOL ON 
SET VERIFY OFF

SET TERMOUT OFF
COLUMN 1 NEW_VALUE 1
COLUMN 2 NEW_VALUE 2
SELECT '' "1" FROM DUAL WHERE ROWNUM = 0;
DEF DBNAME='&1'
SET HEADING ON
SET TERMOUT ON

BREAK ON fred SKIP 1
COLUMN fred noprint
COLUMN db_name FORMAT a15 HEADING 'Database Name'
COLUMN server FORMAT a50 HEADING 'Server'
COLUMN input_type FORMAT a20 HEADING 'Backup Type'
COLUMN status FORMAT a30 HEADING 'Status'
COLUMN last_time FORMAT a45 HEADING 'Date/Time'

PROMPT
PROMPT ####################################################################################################################################################################################
PROMPT #                                                  The latest backup summary information from the RMAN catalog
PROMPT #                                                 ==============================================================
PROMPT #
PROMPT # This shows the most recent successes and failures for the last week or thereabouts.
PROMPT #
PROMPT # N.B. If you don't see entries for all databases here, find out why and rectify if possible!
PROMPT #
PROMPT ####################################################################################################################################################################################

COLUMN db_name FORMAT a30 HEADING 'Database Name'
SELECT d.database_name AS fred,
       d.database_name  || CASE WHEN r.db_name = d.database_name THEN NULL ELSE ' (' || r.db_name ||  ')' END AS db_name,
       NVL(d.server || DECODE(s.physical_server,s.server,'',' (' || s.physical_server || ')'),'???') AS server,
       r.input_type,
       r.status,
       r.last_time
FROM   amo.rman_details  r,
       amo.am_database d,
       amo.am_server s
WHERE  d.database_name LIKE DECODE('&DBNAME','','%','&DBNAME')
AND    r.dbid = d.dbid (+)
AND    s.server = d.server
ORDER BY fred, database_name, server, input_type, status, last_time DESC
/

SET FEEDBACK ON

PROMPT N.B. Backups are displayed based on the database DBID. If databases have the same DBID then the information shown may be from another database!
PROMPT To help make sense of this the database_name held in the RMAN catalog is shown in brackets where there is a possible discrepancy.
PROMPT However this can also be the case when the database name in amchecks (and in tnsnames.ora) is different from the database name.
PROMPT 
PROMPT To avoid this mess keep database name unique across the board if possible. If not then ensure that DBID is unique across the board even for read only databases.
PROMPT Also ensure that reconcile.ksh is run periodically and also as soon as any database has its DBID changed otherwise you wont see correct backup details here.
PROMPT
PROMPT The following DBIDs are NOT UNIQUE:

SELECT dbid, 
       database_name 
FROM   am_database 
WHERE  dbid IN (SELECT dbid FROM am_database 
                WHERE  dbid IS NOT NULL 
                GROUP BY dbid HAVING COUNT(*) > 1) 
ORDER BY dbid;

PROMPT
PROMPT The following have no backup for the last week 

SELECT db_name, 
       dbid
FROM   amo.rman_missing_backups
/

col db format a24
col status format a20
col last_time format a50

PROMPT
PROMPT Last recorded database backups for each database in the last year (beware false reporting for duplicate DBIDs again) 
PROMPT Also remember that databases listed here may also be registered in other catalogs
PROMPT

SELECT db, status, last_time, dbid FROM amo.rman_last_backup;

PROMPT
PROMPT Please ensure that the following directories are being backedup (to tape, offsite etc) or secured in some other way:
PROMPT Again, if you have databases with the same DBID then results will be misleading!
PROMPT

COLUMN directory FORMAT a80 HEADING 'Directory'
COLUMN db_name FORMAT a20 HEADING 'Database Name'

SET feedback off

--SELECT NVL(d.server || DECODE(s.physical_server,s.server,'',' (' || s.physical_server || ')'),'???') AS server,
--       v.name AS db_name,
--       v.directory
--FROM   amo.rman_backup_directories v,
--       amo.am_database d,
--       amo.am_server s
--WHERE  v.name = d.database_name (+)
--AND    s.server = d.server 
--ORDER BY s.physical_server, 1,2,3

COL name FORMAT A35
COL dbid FORMAT A24
COL directory FORMAT A80
SET LINES 150

SELECT s.physical_server_abbrev || ' (' || a.database_name || ')' as name,
       'DBID:' || TO_CHAR(b.dbid) AS dbid,
       b.directory
FROM   amo.rman_backup_directory b,
       amo.am_database a,
       amo.am_server s
WHERE  b.dbid = a.dbid
AND    a.server = s.server
ORDER BY 1,2,3
/

PROMPT

