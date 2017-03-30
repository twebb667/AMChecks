--
-- Author: Tony Webb 16th Nov 2016
--
-- N.B. Please grant the following bfore implementing this script:
--
-- GRANT select ON apps.fnd_svc_components TO amu;
-- GRANT select ON apps.fnd_concurrent_queues_vl TO amu;
--
-- These checks are only relevant on 'r12' databases and are not intended to replace any other 
-- checks normally in place for an e-business database.
--

SET FEEDBACK OFF
SET SERVEROUTPUT ON
SET LINES 400

COLUMN component_name   FORMAT a45
COLUMN component_status FORMAT a15
COLUMN machine          FORMAT a20
COLUMN module           FORMAT a30
COLUMN osuser           FORMAT a10
COLUMN program          FORMAT a30
COLUMN serial#          FORMAT 99999
COLUMN sid              FORMAT 9999
COLUMN spid             FORMAT a8
COLUMN startup_mode     FORMAT a15
COLUMN status           FORMAT a15
COLUMN username         FORMAT a15

DECLARE

    TYPE t_compdetstatus IS RECORD (component_name   VARCHAR2(80),
                                    startup_mode     VARCHAR2(30),
                                    component_status VARCHAR2(30));

    TYPE t_compdet IS TABLE OF t_compdetstatus;

    v_compdet           t_compdet;

    v_rowcount          PLS_INTEGER:=0;
    v_send_mail         CHAR(1):='N';

BEGIN

      SELECT fsc.COMPONENT_NAME,
             fsc.STARTUP_MODE,
             fsc.COMPONENT_STATUS
      BULK COLLECT INTO v_compdet
      FROM   apps.fnd_concurrent_queues_vl fcq, 
             apps.fnd_svc_components fsc
      WHERE  fsc.concurrent_queue_id = fcq.concurrent_queue_id(+)
      AND    fsc.startup_mode = 'AUTOMATIC'
      AND    fsc.component_status <> 'RUNNING'
      ORDER BY component_status, startup_mode, component_name;

      FOR i IN 1 .. v_compdet.COUNT
      LOOP
          DBMS_OUTPUT.PUT_LINE('** WARNING: ' || RPAD(v_compdet(i).component_name,45) || ' (' || v_compdet(i).startup_mode || ') ' || v_compdet(i).component_status || ' **');
      END LOOP;

      v_rowcount := SQL%ROWCOUNT;
      IF (v_rowcount > 0 )
      THEN
          v_send_mail := 'Y';
      END IF;

END;
/

