set pages 1000
set lines 300
col metric format a32

 WITH s1 AS (SELECT
--    z.database_name,
--    z.server,
    z.metric,
    z.space_time,
    z.now_value,
    z.min1_value,
    z.min2_value,
    z.min3_value,
    z.min6_value,
    z.min9_value,
    z.min12_value
 FROM
    (SELECT  database_name,
             server,
             metric,
             space_time,
             value AS now_value,
             LAG(value, 1, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min1_value,
             LAG(value, 2, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min2_value,
             LAG(value, 3, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min3_value,
             LAG(value, 6, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min6_value,
             LAG(value, 9, NULL)  OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min9_value,
             LAG(value, 12, NULL) OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time, value) AS min12_value,
             ROW_NUMBER() OVER (PARTITION BY database_name, server, metric ORDER BY database_name, server, metric, space_time desc) AS rn
      FROM   amo.am_metric_hist) z
 WHERE z.rn = 1
 GROUP BY z.database_name, z.server, z.metric, z.space_time, z.now_value, 
          z.min1_value, z.min2_value, z.min3_value, min6_value, min9_value, min12_value
 ORDER BY z.database_name, z.server, z.metric, z.space_time),
s2 AS ( SELECT
--    m.database_name,
--    m.server,
    t.metric,
    m.now_value,
    f.qtrhour_av,
    h.hday_av,
    w.twohour_av,
    s.sixhour_av,
    t.today_av,
    y.yday_av
 FROM
    (SELECT  database_name,
             server,
             metric,
             AVG(value) AS now_value
      FROM   amo.am_metric_hist
      WHERE  space_time > sysdate - 6/1440
      GROUP BY database_name, server, metric) m,
      (SELECT  database_name,
             server,
             metric,
             AVG(value) AS qtrhour_av
      FROM   amo.am_metric_hist
      WHERE  space_time > sysdate - 15/1440
      GROUP BY database_name, server, metric) f,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS yday_av
       FROM   amo.am_metric_hist
       WHERE  space_time < trunc(sysdate) and space_time > trunc(sysdate) -2
       GROUP BY database_name, server, metric) y,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS hday_av
       FROM   amo.am_metric_hist
       WHERE  space_time < (sysdate +1/24) 
       AND    space_time >= (sysdate -1/24)
       GROUP BY database_name, server, metric) h,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS twohour_av
       FROM   amo.am_metric_hist
       WHERE  space_time < (sysdate +1/24) 
       AND    space_time >= (sysdate -2/24)
       GROUP BY database_name, server, metric) w,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS sixhour_av
       FROM   amo.am_metric_hist
       WHERE  space_time < (sysdate +1/24) 
       AND    space_time >= (sysdate -6/24)
       GROUP BY database_name, server, metric) s,
      (SELECT database_name,
              server,
              metric,
              AVG(value) AS today_av
       FROM   amo.am_metric_hist
       WHERE  space_time > TRUNC(sysdate)
       GROUP BY database_name, server, metric) t
 WHERE t.database_name = y.database_name (+)
 AND   t.server = y.server (+)
 AND   t.metric = y.metric (+)
 AND   t.database_name = f.database_name (+)
 AND   t.server = f.server (+)
 AND   t.metric = f.metric (+)
 AND   t.database_name = h.database_name (+)
 AND   t.server = h.server (+)
 AND   t.metric = h.metric (+)
 AND   t.database_name = m.database_name (+)
 AND   t.server = m.server (+)
 AND   t.metric = m.metric (+)
 AND   t.database_name = w.database_name (+)
 AND   t.server = w.server (+)
 AND   t.metric = w.metric (+)
 AND   t.database_name = s.database_name (+)
 AND   t.server = s.server (+)
 AND   t.metric = s.metric (+)
 GROUP BY t.database_name, t.server, t.metric, m.now_value, f.qtrhour_av, y.yday_av, h.hday_av, t.today_av, w.twohour_av, s.sixhour_av
 ORDER BY t.database_name, t.server, t.metric)
SELECT 
    s1.metric,
    TO_CHAR(s1.space_time,'DD-MM-YY hh24:mi:ss') "Time",
    '|' " ",
    s1.now_value "Now",
    s1.min1_value "-5 min",
    s1.min2_value "-10 min",
    s1.min3_value "-15 min",
    s1.min6_value "-30 min",
    s1.min9_value "-45 min",
    s1.min12_value "-60 min",
    '|' " ",
    s2.qtrhour_av "15 min avg",
    s2.hday_av "Hour avg",
    s2.twohour_av "2 Hr avg",
    s2.sixhour_av "6 Hr avg",
    s2.today_av "Today avg",
    s2.yday_av "Y-Day avg"
FROM s1, s2
WHERE s1.metric=s2.metric
ORDER BY 1;
-- exit;

