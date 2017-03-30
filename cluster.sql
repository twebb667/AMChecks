SELECT d.database_name || ' server?' ||
               SUBSTR(s.physical_server,1, INSTR(s.physical_server, '.')-1) ||
              CASE WHEN s.cluster_name IS NULL THEN NULL ELSE ' cluster?' || s.cluster_name END AS cluster_name
       FROM   amo.am_database d,
              amo.am_server s
       WHERE  d.server = s.server
       ORDER BY 1;

