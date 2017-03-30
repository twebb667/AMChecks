
WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;
SET PAGES 1000
SET FEEDBACK off
SET LINES 200
SET TAB OFF

COL dblink FORMAT a120 HEADING "DB Link"

select owner || '.' || db_link || ' =>' || username || '@' || host as dblink from dba_db_links;
exit;

