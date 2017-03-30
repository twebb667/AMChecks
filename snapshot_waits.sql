--
-- from Jonathan Lewis's Site.
--
COLUMN snap_waits   FORMAT 999,999,990
COLUMN snap_waited  FORMAT 999,999,990
COLUMN wait_average FORMAT 999,999.99
SET PAGES 1000

SELECT TO_CHAR(snap_time,'Mon-dd hh24:mi:ss') AS  time_stamp,
      total_waits - prev_waits                AS  snap_waits,
      time_waited - prev_time                 AS  snap_waited,
      ROUND((time_waited - prev_time) /
            DECODE((total_waits - prev_waits), 0,null,
                   (total_waits - prev_waits)), 2) AS wait_average
FROM
      (
      SELECT
--    starting query: get current and previous values
--    The division by 10,000 converts 9i values centiseconds.
            ss.snap_time,
            se.total_waits,
            LAG(se.total_waits,1) OVER (ORDER BY se.snap_id)             AS prev_waits,
            se.time_waited_micro/10000                                   AS time_waited,
            LAG(se.time_waited_micro/10000,1) OVER (ORDER BY se.snap_id) AS prev_time
      FROM  perfstat.stats$snapshot       ss,
            perfstat.stats$system_event   se
      WHERE ss.snap_time BETWEEN sysdate - 1 AND sysdate
      AND   se.snap_id = ss.snap_id
      AND   se.event = 'db file sequential read'
      --
      --    Technically I should include the DBID and INSTANCE_NUMBER in the
      --    join, as these are part of the primary keys of the two tables.
      --    But most people have just one instance and one database.
      )
WHERE total_waits - prev_waits >= 0       -- dirty trick to skip instance restarts
ORDER BY snap_time 
/
