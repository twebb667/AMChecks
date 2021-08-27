    set lines 200
    ALTER SESSION SET NLS_DATE_FORMAT='dd-mm-yy';
    SELECT RPAD(tablespace_name,30),
           TO_CHAR(used_space, '9,990.99')
    FROM   (SELECT tablespace_name, used_space, last_value(space_time) 
            OVER (PARTITION BY tablespace_name ORDER BY space_time) AS latest 
            FROM amo.am_database_space 
              WHERE database_name = 'ORCL_or_whatever'
            ORDER BY tablespace_name)
    WHERE space_time = latest;
