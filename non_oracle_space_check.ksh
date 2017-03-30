#!/bin/ksh
##################################################################################
# Name             : non_oracle_space_check.ksh
# Author           : Tony Webb
# Created          : 09 JAN 2017
# Type             : Korn shell script
# Version          : 070
# Parameters       : -a alternate_email
#                    -m (mail)
#                    -s  server
#		     -S (smart mail)
#                    -r mins (reminder)
# Returns          : 0   Success
#                    50  Wrong parameters
#
# Notes            : Must call all_os_space_check.ksh 
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 09/01/17 | T. Webb    | Original
# 020     | 11/01/17 | T. Webb    | -S added (only e-mail if errors found)
# 030     | 12/01/17 | T. Webb    | Attempts to make -S smarter
#         |          |            | .. and adding -r (reminder)
# 040     | 12/01/17 | T. Webb    | Added -r
# 050     | 16/01/17 | T. Webb    | Join to am_space_threshold
# 060     | 16/01/17 | T. Webb    | Formatting changes
# 070     | 17/01/17 | T. Webb    | Changes to alerting rules
#################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environments for the morning checks
. ${AMCHECK_DIR}/.amcheck

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -c (cron mode) -m (mail) -s server (defaults to all) -s (smart mail) -h heading"

typeset CRON_MODE='N'
typeset DATABASE
typeset DETAIL_FILE="${TEMP_DIR}/non_oracle_am_os_space_history.txt"
typeset -i DIFF=0
typeset OS_CHECK_DIR
typeset EXTERNAL_DIR
typeset LANG=en_GB
typeset LINE
typeset MAIL_BUFFER="${TEMP_DIR}/non_oracle_os_space_check_mail"
typeset MAIL_TITLE='OS_Space_Check_Summary'
typeset -i REMINDER_TIME=60
typeset -i ROWCOUNT=0
typeset SEND_MAIL='N'
typeset TEMPFILE1="${TEMP_DIR}/non_oracle_os_space_check1.lst"
typeset TEMPFILE2="${TEMP_DIR}/non_oracle_os_space_check2.lst"
typeset TEMPFILE3="${TEMP_DIR}/non_oracle_os_space_check3.lst"
export TNS_ADMIN
# Note that the filename below is currently hard-coded into the pl/sql code..
typeset VERBOSE_FILE="${TEMP_DIR}/non_oracle_am_os_space_verbose.txt"

#############
# Functions
#############

function f_run
{
    #########################################################
    # Populate the flatfile/datafile for the external tables
    #########################################################

    typeset SERVER=$1
    typeset -i AGE=64
    typeset START_DATE=`date +%d-%m-%y:%H.%M.%S`

    cd ${OS_CHECK_DIR}
    if [[ ! -r ${SERVER}_os_space.dbf ]]
    then
        echo "Expected file ${OS_CHECK_DIR}/${SERVER}_os_space.dbf not found or is not readable."
        exit 97
    fi

    if [[ `find ${OS_CHECK_DIR} -name ${SERVER}_os_space.dbf -mmin -${AGE} | wc -l ` -gt 1 ]]
    then
        echo "File ${OS_CHECK_DIR}/${SERVER}_os_space.dbf is more than ${AGE} minutes old!"
        exit 96
    fi

    cp ${OS_CHECK_DIR}/${SERVER}_os_space.dbf ${EXTERNAL_DIR}/non_oracle_os_space_load.dbf
    if [[ $? -ne 0 ]]
    then
        echo "Error copying ${OS_CHECK_DIR}/${SERVER}_os_space.dbf  to ${EXTERNAL_DIR}_temp.dbf"
        exit 95
    fi

sqlplus -s ${AMCHECK_TNS} <<- SQL100 > ${TEMPFILE1}
	ALTER SESSION SET NLS_DATE_FORMAT='DD-MM-YY HH24:MI:SS';
	SET PAGES 0
	SET FEEDBACK OFF
	SET TAB OFF
	SET LINES 300
	SELECT  server || ', ' || filesystem || ', ' || sizek || ', ' || usedk || ', ' || availk || ', ' || pctused || ', ' || mountpoint || ', ' || df_dow || ', ' || df_timestamp 
	FROM am_non_oracle_space_load;
    	MERGE INTO amo.am_os_space a
	USING
	(SELECT server, filesystem, sizek, usedk, availk, pctused, mountpoint, TO_DATE(SUBSTR(df_timestamp,1,24),'Dy-dd-Mon-yyyy-HH24:MI:SS') AS space_time
	FROM am_non_oracle_space_load) b
	ON (a.server = b.server AND a.mountpoint = b.mountpoint AND a.space_time = b.space_time)
	WHEN MATCHED THEN
	UPDATE SET a.filesystem = b.filesystem, a.sizek = b.sizek, a.usedk = b.usedk, a.availk = b.availk, a.pctused = b.pctused
	WHEN NOT MATCHED THEN
	INSERT (a.server, a.filesystem, a.sizek, a.usedk, a.availk, a.pctused, a.mountpoint, a.space_time)
	VALUES (b.server, b.filesystem, b.sizek, b.usedk, b.availk, b.pctused, b.mountpoint, b.space_time);
	DELETE FROM amo.am_os_space WHERE space_time < trunc(sysdate)-42 AND server = ${SERVER};
	commit;
	exit;
SQL100

sqlplus -s ${AMCHECK_TNS} <<- SQL200 > ${TEMPFILE2}
	SET PAGES 1000
	SET FEEDBACK OFF
	SET LINES 170
	COL day_growth               FORMAT 990 
	COL day_growth_string        FORMAT A10 HEADING 'Day Growth'
	COL month_growth             FORMAT 990 
	COL month_growth_string      FORMAT A8 HEADING 'Mth Growth'
	COL mountpoint               FORMAT A40 HEADING 'Mountpoint'
	COL now_pctused              FORMAT 990 
	COL now_pctused_string       FORMAT A5 HEADING 'Today'
	COL lastmonth_pctused_string FORMAT A8 HEADING 'Last Mth'
	COL lastweek_pctused_string  FORMAT A7 HEADING 'Last Wk'
	COL server                   FORMAT A20 HEADING 'Server'
	COL week_growth              FORMAT 990 
	COL week_growth_string       FORMAT A7 HEADING 'Wk Growth'
	COL yesterday_pctused_string FORMAT A9 HEADING 'Yesterday'
	
	SET TERMOUT ON
	SET SERVEROUTPUT ON
	
	prompt
	prompt OS Space Alerts
	prompt ================
	prompt
	
	DECLARE
    	fileHandler UTL_FILE.FILE_TYPE;

    	TYPE  t_space IS RECORD (server     VARCHAR2(30),
                             	mountpoint VARCHAR2(200),
                               	pctused    NUMBER(3,0),
                               	sizek      NUMBER(10,0), 
                               	usedk      NUMBER(10,0), 
                               	availk     NUMBER(10,0), 
  	                     	space_time DATE);

    	TYPE  t_space_tab IS TABLE OF t_space;
    	v_space t_space_tab := t_space_tab();
    	v_rec_count      PLS_INTEGER:=0;
	
    	v_day_growth_string     VARCHAR2(10);
    	v_error_size            VARCHAR2(10);
    	v_week_growth_string    VARCHAR2(10);
    	v_month_growth_string   VARCHAR2(10);
	
	------------------------------------------------------------------
	-- These are the values used to determine the alerting thresholds
	-- for the main select
	------------------------------------------------------------------
	
    	v_threshold_day           PLS_INTEGER:=80;
    	v_threshold_week          PLS_INTEGER:=60;
    	v_threshold_month         PLS_INTEGER:=50;

	BEGIN

	fileHandler := UTL_FILE.FOPEN('AMCHECK_TEMP', 'non_oracle_temp.txt', 'W');
	
	DBMS_OUTPUT.PUT_LINE('Server               Mountpoint                               Today  Yday Lst Wk Lst Mth Dy Grow  Wk Grow Mth Grow  Used(KB)  Alert Size  Alert');
	DBMS_OUTPUT.PUT_LINE('-------------------- ---------------------------------------- -----  ---- ------ ------- -------- ------- -------- ---------- ----------- --------------');
	
	FOR c1 IN (
	WITH now_info AS
     	    (SELECT DISTINCT *
     	     FROM (SELECT s.server, s.mountpoint, s.filesystem, NVL(s.pctused,0) AS now_pctused, s.space_time AS now_space_time, 
                          s.usedk AS usedk,
                              RANK() OVER (PARTITION BY s.server, s.mountpoint, filesystem ORDER BY s.server, s.mountpoint, s.filesystem, s.space_time DESC, s.usedk) AS my_rownum
                   FROM   amo.am_os_space s
                   WHERE  s.server = '${SERVER}'
                   AND    s.space_time >= trunc(sysdate))
     	     WHERE   my_rownum = 1
     	     ORDER BY server, mountpoint, now_space_time, now_pctused),
        yesterday_info AS
	(SELECT DISTINCT *
     	     FROM (SELECT s.server, s.mountpoint, NVL(s.pctused,0) AS yesterday_pctused, s.space_time AS yesterday_space_time,
                         RANK() OVER (PARTITION BY s.server, s.mountpoint ORDER BY s.server, s.mountpoint, s.space_time DESC) AS my_rownum
                   FROM   amo.am_os_space s
                   WHERE  s.server = '${SERVER}'
            	   AND    s.space_time < trunc(sysdate) AND s.space_time >= trunc(sysdate-7))
     	     WHERE   my_rownum = 1
             ORDER BY server, mountpoint, yesterday_space_time, yesterday_pctused),
	lastweek_info AS
    	(SELECT DISTINCT *
     	     FROM (SELECT s.server, s.mountpoint, NVL(s.pctused,0) AS lastweek_pctused, s.space_time AS lastweek_space_time,
                         RANK() OVER (PARTITION BY s.server, s.mountpoint ORDER BY s.server, s.mountpoint, s.space_time DESC) AS my_rownum
                   FROM   amo.am_os_space s
                   WHERE  s.server = '${SERVER}'
      		AND     s.space_time <= trunc(sysdate-7) AND s.space_time >= trunc(sysdate-13))
     	        WHERE   my_rownum = 1
            	ORDER BY server, mountpoint, lastweek_space_time, lastweek_pctused),
	lastmonth_info AS
    	(SELECT DISTINCT *
     	     FROM (SELECT s.server, s.mountpoint, NVL(s.pctused,0) AS lastmonth_pctused, s.space_time AS lastmonth_space_time,
                         RANK() OVER (PARTITION BY s.server, s.mountpoint ORDER BY s.server, s.mountpoint, s.space_time DESC) AS my_rownum
                   FROM   amo.am_os_space s
                   WHERE  s.server = '${SERVER}'
            	AND     s.space_time <= trunc(sysdate-13) AND s.space_time >= trunc(sysdate-62))
     	        WHERE   my_rownum = 1
            	ORDER BY server, mountpoint, lastmonth_space_time, lastmonth_pctused)
	SELECT DISTINCT server,
       	mountpoint,
       	' ' ||    now_pctused || '%'       AS now_pctused_string,
       	'   ' ||  yesterday_pctused || '%' AS yesterday_pctused_string,
       	'  ' ||   lastweek_pctused || '%'  AS lastweek_pctused_string,
       	'  ' ||   lastmonth_pctused || '%' AS lastmonth_pctused_string,
       	'    ' || day_growth || '%'        AS day_growth_string,
       	'   ' ||  week_growth || '%'       AS week_growth_string,
       	'   ' ||  month_growth || '%'      AS month_growth_string,
       	noydata,
       	nolwdata,
       	nolmdata,
	usedk,
	error_size_in_k,
        status
	FROM (
	SELECT DISTINCT n.server,
       	n.mountpoint,
       	n.now_pctused,
       	DECODE(y.yesterday_pctused,NULL,'*',' ') AS noydata,
       	DECODE(l.lastweek_pctused,NULL,'*',' ') AS nolwdata,
       	DECODE(m.lastmonth_pctused,NULL,'*',' ') AS nolmdata,
       	NVL(y.yesterday_pctused, 0) AS yesterday_pctused,
       	NVL(l.lastweek_pctused, NVL(y.yesterday_pctused, 0)) AS lastweek_pctused,
       	NVL(m.lastmonth_pctused, NVL(l.lastweek_pctused, NVL(y.yesterday_pctused, 0))) AS lastmonth_pctused,
       	NVL((n.now_pctused - NVL(y.yesterday_pctused, 0)),0) AS day_growth,
       	NVL((n.now_pctused - NVL(l.lastweek_pctused, NVL(y.yesterday_pctused, 0))),0)  AS week_growth,
       	NVL((n.now_pctused - NVL(m.lastmonth_pctused, NVL(l.lastweek_pctused, NVL(y.yesterday_pctused, 0)))),0)  AS month_growth,
	n.usedk, t.error_size_in_k,
       	(CASE 
/* Day growth */   WHEN (n.now_pctused IS NOT NULL) 
                    AND (y.yesterday_pctused IS NOT NULL) 
                    AND (n.now_pctused > y.yesterday_pctused) 
                    AND ((n.now_pctused > NVL(t.error_pct_day,v_threshold_day)) OR
                         (n.now_pctused - y.yesterday_pctused) * 4 >= (100 - n.now_pctused))
                   THEN '*ERROR (day)*'
/* Week growth */  WHEN (n.now_pctused IS NOT NULL) 
                    AND (l.lastweek_pctused IS NOT NULL) 
                    AND (n.now_pctused > l.lastweek_pctused) 
                    AND (n.now_pctused > y.yesterday_pctused) 
                    AND ((n.now_pctused > NVL(t.error_pct_week,v_threshold_week)) OR
                         (n.now_pctused - l.lastweek_pctused) * 2 >= (100 - n.now_pctused))
                   THEN '*ERROR (wk)*'
/* Month growth */ WHEN (n.now_pctused IS NOT NULL) 
                    AND (m.lastmonth_pctused IS NOT NULL) 
                    AND (n.now_pctused > m.lastmonth_pctused) 
                    AND (n.now_pctused > y.yesterday_pctused) 
                    AND ((n.now_pctused > NVL(t.error_pct_month,v_threshold_month)) OR
                         (n.now_pctused - m.lastmonth_pctused) >= (100 - n.now_pctused))
                   THEN '*ERROR (mth)*'
/* Current Size */ WHEN (n.usedk > t.error_size_in_k) 
                   THEN '*ERROR (size)*'
           	ELSE ' '
       	END) AS status
	FROM   now_info n,
       		yesterday_info y,
 		lastweek_info l,
       		lastmonth_info m,
		amo.am_space_threshold t
	WHERE  n.server = y.server (+)
	AND    n.server = t.server (+)
	AND    n.filesystem = t.filesystem(+)
	AND    n.mountpoint = y.mountpoint(+)
	AND    n.server = l.server (+)
	AND    n.mountpoint = l.mountpoint (+)
	AND    n.server = m.server (+)
	AND    n.mountpoint = m.mountpoint (+)
AND n.server = '${SERVER}'
	)
	ORDER BY server
	)
	LOOP
   	if (c1.noydata = '*')
   	then
       		v_day_growth_string := '(N/A)';      
   	else
       		v_day_growth_string := c1.day_growth_string;
   	end if;
	
   	if (c1.nolwdata = '*')
   	then
       		v_week_growth_string := '(N/A)';      
   	else
       		v_week_growth_string := c1.week_growth_string;
   	end if;
	
   	if (c1.nolmdata = '*')
   	then
       		v_month_growth_string := '(N/A)';      
   	else
       		v_month_growth_string := c1.month_growth_string;
   	end if;
	
   	if (c1.error_size_in_k IS NULL)
   	then
       		v_error_size := '(N/A)';      
   	else
       		v_error_size := TO_CHAR(c1.error_size_in_k);
   	end if;
	
   	DBMS_OUTPUT.PUT_LINE(RPAD(c1.server,20) || ' ' ||
                        	RPAD(c1.mountpoint,40) || ' ' ||
                        	LPAD(c1.now_pctused_string,5) || ' ' ||
                        	LPAD(c1.yesterday_pctused_string,6) || ' ' ||
                        	LPAD(c1.lastweek_pctused_string,5) || ' ' ||
                        	LPAD(c1.lastmonth_pctused_string,6) || ' ' ||
                        	LPAD(v_day_growth_string,8) || ' ' ||
                        	LPAD(v_week_growth_string,7) || ' ' ||
                        	LPAD(v_month_growth_string,9) || ' ' ||
                        	LPAD(c1.usedk,10,' ') || ' ' ||
--                        	LPAD(NVL(TO_CHAR(c1.error_size_in_k),' '),11,' ') ||
                        	LPAD(v_error_size,11) ||
                                ' ' || c1.status);
    	v_rec_count:= v_rec_count + 1;
	
    	-- Dump out recent space records for each server+mountpoint should it be needed later 
    	-- Note that BULK COLLECT will overwrite previous iterations so I'm writing to a file.
	
    	SELECT  DISTINCT server, mountpoint, pctused, sizek, usedk, availk, space_time 
    	BULK COLLECT INTO v_space
    	FROM    amo.am_os_space
    	WHERE   server = c1.server
    	AND     mountpoint = c1.mountpoint
    	AND     space_time > trunc(sysdate)-14;
	
    	if (v_space.COUNT > 0)
    	then
        	FOR ix IN v_space.FIRST .. v_space.LAST 
        	LOOP
           	UTL_FILE.PUTF(fileHandler, RPAD(v_space(ix).server,20) || ' ' ||
                                      	RPAD(v_space(ix).mountpoint||'.',40) || ' ' || 
                                      	RPAD(TO_CHAR(v_space(ix).pctused,'990') || '%' ,6) || ' ' || 
                                      	TO_CHAR(v_space(ix).space_time,'Dy DD-MM-YY HH24:MI:SS') || '\n');
        	END LOOP;
    	end if;
    	UTL_FILE.PUTF(fileHandler, '\n');
	
	END LOOP;
	
  	UTL_FILE.FCLOSE(fileHandler);
	
	EXCEPTION
  	WHEN utl_file.invalid_path THEN
     	raise_application_error(-20000, 'ERROR: Invalid PATH FOR file.');
	END;
	/
SQL200

cat ${TEMP_DIR}/non_oracle_temp.txt >> ${VERBOSE_FILE}

}

#######
# Main
#######

# Read standard amchecks functions
. ${AMCHECK_DIR}/functions.ksh

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!

while getopts a:mr:s:S o
do      case "$o" in
        a)      MAIL_RECIPIENT="${OPTARG}"
                SEND_MAIL="Y";;
        m)      SEND_MAIL="Y";;
        r)      REMINDER_TIME="${OPTARG}"
                SEND_MAIL="M";;
        s)      SERVER="${OPTARG}";;
        S)      SEND_MAIL="M";;
        [?])    print -- "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -gt 0 ]]
then
    echo "Don't specify any positional parameters. ${USAGE}"
fi

# The below stops any problems used by odd combination of mail flags
if [[ ${SMART_MAIL} == "Y" ]]
then
    SEND_MAIL='M'
fi

OS_CHECK_DIR="${AMCHECK_DIR}/os_space_checks"
EXTERNAL_DIR="${AMCHECK_DIR}/external_tables"

echo " " > ${VERBOSE_FILE}
echo " " > ${DETAIL_FILE}
echo "Recent growth by mountpoint" >> ${DETAIL_FILE}
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~" >> ${DETAIL_FILE}
echo " " >> ${DETAIL_FILE}

if [[ ! -d ${EXTERNAL_DIR} ]]
then
   echo "No external directory. Please create ${EXTERNAL_DIR}"
   exit 51
fi

if [[ ! -d ${OS_CHECK_DIR} ]]
then
   echo "No os_check_dir directory. Please create ${OS_CHECK_DIR}"
   exit 51
fi

if [[ ! -z ${SERVER} ]]
then
    MAIL_TITLE="${SERVER}_${MAIL_TITLE}"
    if [[ ! -r ${OS_CHECK_DIR}/${SERVER}_os_space.dbf ]]
    then
        echo "No space report file found for server ${SERVER}"
        exit 98
    else
       f_run "${SERVER}"
    fi
else
    echo "All servers will be checked.."
    MAIL_TITLE="non_oracle_${MAIL_TITLE}"
    cd ${OS_CHECK_DIR}
    for SERVER in `ls -1 *_os_space.dbf  | cut -d'_' -f1`
    do
       f_run "${SERVER}"
    done
fi

grep -i 'error' ${TEMPFILE2}  > ${TEMP_DIR}/new_non_oracle_error_summary
if [[ ! -r ${TEMP_DIR}/prev_non_oracle_error_summary ]]
then
    touch ${TEMP_DIR}/prev_non_oracle_error_summary
fi

if [[ ! -r ${TEMP_DIR}/new_non_oracle_error_summary ]]
then
    touch ${TEMP_DIR}/new_non_oracle_error_summary
fi

DIFF=`diff ${TEMP_DIR}/prev_non_oracle_error_summary ${TEMP_DIR}/new_non_oracle_error_summary 2>/dev/null | wc -l`
if [[ ${DIFF} -gt 0 ]] ||
   [[ `find ${TEMP_DIR} -name "prev_non_oracle_error_summary" -mmin +${REMINDER_TIME} | wc -l` -gt 0 ]] 
then
    if [[ ${SEND_MAIL} == "M" ]] 
    then
        SEND_MAIL='Y'
    fi
    cp ${TEMP_DIR}/new_non_oracle_error_summary ${TEMP_DIR}/prev_non_oracle_error_summary
fi

# Need to just include filesystems highlighted in either the previous or new error log files
   
cat ${VERBOSE_FILE} | while read LINE
do
MOUNTPOINT=`echo ${LINE} | cut -d'/' -f2- | cut -d' ' -f1 `
if [[ ! -z ${MOUNTPOINT} ]]
then
    if [[ `grep -cw "/${MOUNTPOINT}" ${TEMP_DIR}/prev_non_oracle_error_summary` -gt 0 ]] ||
       [[ `grep -cw "/${MOUNTPOINT}" ${TEMP_DIR}/new_non_oracle_error_summary` -gt 0 ]] 
    then
       echo ${LINE} >> ${DETAIL_FILE}
#       echo "debug ${LINE}"
    fi
fi
done

cat ${DETAIL_FILE} >> ${TEMPFILE2}
cat ${TEMPFILE2}

if [[ ${SEND_MAIL} == "Y" ]]
then
  echo "Sending Mail"
  echo "Please see attached.." > ${MAIL_BUFFER}
  if [[ `grep -ic error ${TEMPFILE2}` -gt 0 ]]
  then
      MAIL_TITLE="URGENT ${MAIL_TITLE}"
      echo " " >> ${MAIL_BUFFER}
      echo "Server               Mountpoint                               Today  Yday Lst Wk Lst Mth Dy Grow  Wk Grow Mth Grow  Used(KB)  Alert Size  Alert" >> ${MAIL_BUFFER}
      echo "-------------------- ---------------------------------------- -----  ---- ------ ------- -------- ------- -------- ---------- ----------- --------------" >> ${MAIL_BUFFER}
      grep -i error ${TEMPFILE2} >> ${MAIL_BUFFER}
  fi
  f_mail Space_Summary_Alerts blue ${MAIL_RECIPIENT} "${TEMPFILE2}[courier]+${MAIL_BUFFER}" ${MAIL_TITLE}
fi

exit 0

