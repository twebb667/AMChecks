
WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;
SET PAGES 1000
SET HEADING off
SET FEEDBACK off
SET LINES 200
SET SERVEROUTPUT on
SET TAB OFF

prompt ** No RMAN details available for pre-10.2 databases. Please query the RMAN catalog via sqlplus or use rman to check **
