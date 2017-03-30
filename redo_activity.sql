-- Changed AMW 6th May 2015
-- Added redolog size AMW 9th May 2016

WHENEVER OSERROR  EXIT 1;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

SET LINES 130
SET SERVEROUTPUT on
SET FEEDBACK off
SET TAB OFF

DECLARE
      v_bytes         v$log.bytes%TYPE;
      v_logsize       VARCHAR2(2000):=NULL;
BEGIN
      SELECT DISTINCT bytes 
      INTO v_bytes
      FROM v$log 
      WHERE status = 'CURRENT';

      IF (v_bytes > 1073741823)
      THEN
          v_logsize := TO_CHAR(v_bytes/1024/1024/1024,'999,999') || ' GB';
      ELSE
          v_logsize := TO_CHAR(v_bytes/1024/1024,'999,999') || ' MB';
      END IF;

      DBMS_OUTPUT.PUT_LINE('Hourly breakdown of recent redo log generation (redo logs are ' || TRIM(v_logsize) || ' each)');
      DBMS_OUTPUT.PUT_LINE(RPAD('=',76,'='));
      DBMS_OUTPUT.PUT_LINE(CHR(10) ||'Day                 00  01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20  21  22  23');
      DBMS_OUTPUT.PUT_LINE(RPAD('-',115,'-'));
FOR redo_rec IN (
            SELECT day || LPAD(SUM(zero),4) || LPAD(SUM(one),4) || LPAD(SUM(two),4) || LPAD(SUM(three),4) ||
                   LPAD(SUM(four),4) || LPAD(SUM(five),4) || LPAD(SUM(six),4) || LPAD(SUM(seven),4) ||
                   LPAD(SUM(eight),4) || LPAD(SUM(nine),4) || LPAD(SUM(ten),4) || LPAD(SUM(eleven),4) ||
                   LPAD(SUM(twelve),4) || LPAD(SUM(thirteen),4) || LPAD(SUM(fourteen),4) || LPAD(SUM(fifteen),4) ||
                   LPAD(SUM(sixteen),4) || LPAD(SUM(seventeen),4) || LPAD(SUM(eighteen),4) || LPAD(SUM(nineteen),4) ||
                   LPAD(SUM(twenty),4) || LPAD(SUM(twentyone),4) || LPAD(SUM(twentytwo),4) || LPAD(SUM(twentythree),4) AS hourly_breakdown
            FROM (
                   SELECT TO_CHAR(first_time,'Day dd-mm-yy') day,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'00',1,0)),'999') AS zero,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'01',1,0)),'999') AS one,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'02',1,0)),'999') AS two,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'03',1,0)),'999') AS three,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'04',1,0)),'999') AS four,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'05',1,0)),'999') AS five,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'06',1,0)),'999') AS six,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'07',1,0)),'999') AS seven,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'08',1,0)),'999') AS eight,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'09',1,0)),'999') AS nine,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'10',1,0)),'999') AS ten,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'11',1,0)),'999') AS eleven,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'12',1,0)),'999') AS twelve,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'13',1,0)),'999') AS thirteen,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'14',1,0)),'999') AS fourteen,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'15',1,0)),'999') AS fifteen,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'16',1,0)),'999') AS sixteen,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'17',1,0)),'999') AS seventeen,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'18',1,0)),'999') AS eighteen,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'19',1,0)),'999') AS nineteen,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'20',1,0)),'999') AS twenty,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'21',1,0)),'999') AS twentyone,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'22',1,0)),'999') AS twentytwo,
                                  to_char(SUM(decode(to_char(first_time,'HH24'),'23',1,0)),'999') AS twentythree
                   FROM  gv$log_history
                   WHERE TO_DATE(first_time) > sysdate - 8
                   GROUP BY TO_CHAR(first_time,'Day dd-mm-yy'), TO_DATE(first_time)
                   ORDER BY TO_DATE(first_time))
            GROUP BY DAY
            ORDER BY to_date(day,'Day dd-mm-yy'))
      LOOP
           DBMS_OUTPUT.PUT_LINE(redo_rec.hourly_breakdown);
      END LOOP;
END;
/
SET FEEDBACK on


