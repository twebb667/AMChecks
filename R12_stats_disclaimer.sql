
WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;
SET PAGES 1000
SET HEADING off
SET FEEDBACK off
SET LINES 200
SET SERVEROUTPUT on
SET TAB OFF

prompt ** This database has an issue querying the Data Dictionary for table stats reporting so this is currently disabled. **
