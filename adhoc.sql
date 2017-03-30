set lines 120

SET FEEDBACK OFF;
SET SERVEROUTPUT ON
SET LINES 200

DECLARE
    v_host_name         v$instance.host_name%TYPE;
    v_instance_name     v$instance.instance_name%TYPE;
    v_version           VARCHAR2(20);
    v_procedure_date           VARCHAR2(20);
BEGIN

SELECT v.instance_name,
       v.host_name
INTO   v_instance_name,
       v_host_name
FROM     v$instance v 
ORDER BY v.instance_name;

select version
into v_version
from dba_registry
where comp_name = 'Oracle Database Packages and Types';

select to_char(last_ddl_time,'DD-MM-YY HH24:MI:SS') 
into v_procedure_date
from dba_objects where object_name = 'SYNCRN';

DBMS_OUTPUT.PUT_LINE (LPAD('#',146,'#'));
DBMS_OUTPUT.PUT_LINE (v_instance_name || ' running on ' || v_host_name || ' version: ' || v_version || ' and procedure ran on: ' || v_procedure_date);

END;
/

exit;

