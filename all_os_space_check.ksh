#!/bin/ksh
##################################################################################
# Name             : all_os_space_check.ksh
# Author           : Tony Webb
# Created          : 14 JAN 2016
# Type             : Korn shell script
# Version          : 170
# Parameters       : -a  address (alternative e-mail address)
#                    -c  (cron mode)
#                    -d  database (tnsnames entry)
#                    -f  (forced_report)
#                    -t  title
#                    -r  (report_only)
#                    -R  (no_report)
#                    -m  (mail)
#                    -p  (production_only)
#                    -s  (server)
#                    -v  (verbose)
#                    -w  number (weighting applied to thresholds)
#                    -S  (Smart mail - only mail if alerts found)
# Returns          : 0   Success
#                    50  Wrong parameters
#
# Notes            : Mail title needs to be within double quotes.
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 14/01/16 | T. Webb    | Original
# 020     | 19/01/16 | T. Webb    | Month details added
# 030     | 22/01/16 | T. Webb    | Detail option added and 'pl/sql-ised!'
# 040     | 25/01/16 | T. Webb    | Actual checks tightened up
# 050     | 26/01/16 | T. Webb    | Deleting old data. URGENT flag added.
# 060     | 27/01/16 | T. Webb    | -p flag added
# 070     | 01/02/16 | T. Webb    | physical_server column added..
# 080     | 09/02/16 | T. Webb    | -R and -f options added
# 090     | 09/02/16 | T. Webb    | -w parameter added
# 100     | 17/02/16 | T. Webb    | DISTINCT added (need to work out why...)
# 110     | 09/03/16 | T. Webb    | Added os_checks_ind = 'Y'
# 120     | 20/05/16 | T. Webb    | Fixed a -S' bug
# 130     | 20/05/16 | T. Webb    | Added -t and positional parameters
# 140     | 13/07/16 | T. Webb    | Physical server changes
# 160     | 06/09/16 | T. Webb    | Added physical_server_abbrev
# 170     | 09/01/17 | T. Webb    | Added -s (only for reporting section)
#################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environments for the morning checks
. ${AMCHECK_DIR}/.amcheck

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -c (cron mode) -m (mail) -d database (defaults to all) -v (verbose) -h heading positional parameters"

typeset CRON_MODE='N'
typeset DATABASE
typeset DB_FILE="${AMCHECK_DIR}/external_tables/am_all_os_space_load.dbf"
typeset EXTERNAL_DIR
typeset FORCE_STRING=' '
typeset LANG=en_GB
typeset LINE
typeset LOAD_ONLY='N'
typeset MAIL_BUFFER="${TEMP_DIR}/all_os_space_check_mail"
typeset MAIL_TITLE='OS_Space_Check_Summary'
typeset PREV_DB_FILE="${AMCHECK_DIR}/external_tables/am_all_os_space_load_prev.dbf"
typeset PRODUCTION_STRING=' '
typeset REPORT_ONLY='N'
typeset -i ROWCOUNT=0
typeset SEND_MAIL='N'
typeset SERVER   
typeset TEMPFILE1="${TEMP_DIR}/all_os_space_check1.lst"
typeset TEMPFILE2="${TEMP_DIR}/all_os_space_check2.lst"
typeset TEMPFILE3="${TEMP_DIR}/all_os_space_check3.lst"
typeset TEMPFILE4="${TEMP_DIR}/all_os_space_check4.lst"
typeset TEMPFILE5="${TEMP_DIR}/all_os_space_check5.lst"
typeset TEMPFILE6="${TEMP_DIR}/all_os_space_check6.lst"
typeset TNS_ADMIN=${TEMP_DIR}
export TNS_ADMIN
typeset VERBOSE_IND='N'
# Note that the filename below is currently hard-coded into the pl/sql code..
typeset VERBOSE_FILE="${TEMP_DIR}/am_os_space_history.txt"
typeset -i WEIGHTING=0
typeset WHERE_ADDITION=' '

#############
# Functions
#############

function f_run
{
    #########################################################
    # Populate the flatfile/datafile for the external tables
    #########################################################

    typeset -l SID=$1
    typeset -u UC_SID=$1
    typeset START_DATE=`date +%d-%m-%y:%H.%M.%S`
    typeset STOP_DATE

    print -n -- "Processing ${UC_SID}"

    sqlplus -s ${CONNECT}\@${SID} <<- SQL100 > ${TEMPFILE1}
	set lines 300
	set feedback off
	set pages 0
	SELECT  server || ', ' || filesystem || ', ' || sizek || ', ' || usedk || ', ' || availk || ', ' || pctused || ', ' || mountpoint || ', ' || df_dow || ', ' || df_timestamp 
	FROM amu.am_os_space_load;
    	exit;
SQL100

    cat ${TEMPFILE1} | sed '/^$/d' | grep ', ' | while read LINE
    do
        set ${LINE}
        SERVER=${1}
        FILESYSTEM=${2}
        SIZEK=${3}
        USEDK=${4}
        AVAILK=${5}
        PCTUSED=${6}
        MOUNTPOINT=${7}
        DOW=${8}
        DF_TIMESTAMP=${9}
        print -- "${LINE}" >> ${DB_FILE}
    done
    
    STOP_DATE=`date +%d-%m-%y:%H.%M.%S`
    STOP_DAY=${STOP_DATE%%:*}
    STOP_SEC=`echo ${STOP_DATE##*:} | awk -F. '{ print ($1 *3600 ) + ( $2 * 60 ) + $3 }'`
    START_DAY=${START_DATE%%:*}
    START_SEC=`echo ${START_DATE##*:} | awk -F. '{ print ($1 *3600 ) + ( $2 * 60 ) + $3 }'`

    if [[ ${STOP_DAY} != ${START_DAY} ]]
    then
        #######################################################################################
        # assumes 1 day diff max i.e. job ran over midnight but took less than a day in total!
        #######################################################################################
        let "ELAPSED_SECONDS = ${STOP_SEC} - ${START_SEC} + 86400"
    else
        let "ELAPSED_SECONDS = ${STOP_SEC} - ${START_SEC}"
    fi
    print -- " - Completed in ${ELAPSED_SECONDS} Seconds"
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

while getopts a:cd:fmprRSs:t:vw: o
do      case "$o" in
        a)      MAIL_RECIPIENT="${OPTARG}"  
	        SEND_MAIL="Y";;
        c)      CRON_MODE="Y";;
        d)      DATABASE="${OPTARG}";;
	f)      FORCE_STRING=" OR STATUS IS NOT NULL" ;;
	m)      SEND_MAIL="Y";;
	p)      PRODUCTION_STRING=" AND production_ind = 'Y' ";;
	r)      REPORT_ONLY="Y";;
	R)      LOAD_ONLY="Y";;
	v)      VERBOSE_IND="Y";;
	S)      SEND_MAIL="M"
                SMART_MAIL="Y";;
        s)      SERVER="${OPTARG}";;
	t)      MAIL_TITLE="${OPTARG}";;
        w)      WEIGHTING="${OPTARG}";;
        [?])    print -- "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

###########################################################################################################
# We need to get a list of all columns in table am_database in order to validate the positional parameters
###########################################################################################################
sqlplus -s ${AMCHECK_TNS} <<- SQL200 > ${TEMPFILE6}
	set pages 0
	set feedback off
	SELECT column_name FROM all_tab_columns WHERE table_name = 'AM_DATABASE' AND owner = 'AMO' ORDER BY 1;
	exit;
SQL200
################################################################################################################################
# OK. The remaining positional parameters will be null or a list of column names from am_database with a trailing '+Y' or '_N'.
# We need to validate each of these rather than being clunky and add the text directly to the query. This will help protect
# against SQL injection.
################################################################################################################################

if [[ $# -gt 0 ]]
then
    set $*
    for PAR in "$@"
    do
        INDCOLUMN=${PAR%+*}
        YNIND=${PAR##*+}
        if [[ `grep -cw ${INDCOLUMN} ${TEMPFILE6}` -ne 1 ]]
        then
            print -- "${THISSCRIPTNAME}: Column: ${INDCOLUMN} not found! \n${USAGE}"
            exit 50
        else
            if [[ ${YNIND} != 'Y' ]] && [[ ${YNIND} != 'N' ]]
            then
                print -- "${THISSCRIPTNAME}: Please supply parameters in the format of INDICTOR+Y or INDICATOR+N \n${USAGE}"
                exit 50
            elif [[ ${YNIND} == ${INDCOLUMN} ]]
            then
                print -- "${THISSCRIPTNAME}: Please supply parameters in the format of INDICTOR+Y or INDICATOR+N \n${USAGE}"
                exit 50
            fi
            WHERE_ADDITION="${WHERE_ADDITION} AND d1.${INDCOLUMN} = '${YNIND}'"
        fi
    done
fi

# The below stops any problems used by odd combination of mail flags
if [[ ${SMART_MAIL} == "Y" ]]
then
    SEND_MAIL='M'
fi

if [[ ${LOAD_ONLY} == "Y" ]] 
then
    SEND_MAIL='N'
fi

if [[ ${REPORT_ONLY} == "Y" ]] && [[ ${LOAD_ONLY} == "Y" ]]
then
    print -- "You may not specify 'load only' and 'report only' options at the same time."
    exit 50
fi

EXTERNAL_DIR=~oracle/amchecks/external_tables
rm -f ${VERBOSE_FILE}
rm -f ${TEMPFILE4}
    
if [[ ! -d ${EXTERNAL_DIR} ]]
then
   mkdir ${EXTERNAL_DIR}
fi

if [[ ${REPORT_ONLY} == "N" ]]
then
    mv ${DB_FILE} ${PREV_DB_FILE}
    if [[ ! -z ${DATABASE} ]]
    then
        f_run ${DATABASE}
    else
	sqlplus -s ${AMCHECK_TNS} <<- SQL500 > ${TEMPFILE2}
	SET PAGES 0
	SET FEEDBACK OFF
	SELECT database_name FROM amo.am_database WHERE OS_CHECKS_IND = 'Y' AND disabled <> 'Y' ${PRODUCTION_STRING} ORDER BY 1;
	exit;
SQL500
        cat ${TEMPFILE2} | sed '/^$/d' | while read SID
        do
            f_run ${SID}
        done
    fi

#############################
# Populate table am_os_space 
#############################
    sqlplus -s ${AMCHECK_TNS} <<- SQL600 > ${TEMPFILE3}
    ALTER SESSION SET NLS_DATE_FORMAT='DD-MM-YY HH24:MI:SS';
    SET PAGES 0
    SET FEEDBACK OFF
    SET TAB OFF
    MERGE INTO amo.am_os_space a
    USING
    (SELECT server, filesystem, sizek, usedk, availk, pctused, mountpoint, TO_DATE(SUBSTR(df_timestamp,1,24),'Dy-dd-Mon-yyyy-HH24:MI:SS') AS space_time
    FROM am_all_os_space_load) b
    ON (a.server = b.server AND a.mountpoint = b.mountpoint AND a.space_time = b.space_time)
    WHEN MATCHED THEN
    UPDATE SET a.filesystem = b.filesystem, a.sizek = b.sizek, a.usedk = b.usedk, a.availk = b.availk, a.pctused = b.pctused
    WHEN NOT MATCHED THEN
    INSERT (a.server, a.filesystem, a.sizek, a.usedk, a.availk, a.pctused, a.mountpoint, a.space_time)
    VALUES (b.server, b.filesystem, b.sizek, b.usedk, b.availk, b.pctused, b.mountpoint, b.space_time);
exit;
SQL600

fi
## Show points of interest..

if [[ ${LOAD_ONLY} != 'Y' ]]
then
    if [[ -z ${DATABASE} ]]
    then
        DATABASE='%'
    fi
    if [[ -z ${SERVER} ]]
    then
        SERVER='%'
    fi

	sqlplus -s ${AMCHECK_TNS} <<- SQL700 > ${TEMPFILE3}
	SPOOL ${TEMPFILE4}
	SET PAGES 1000
	SET FEEDBACK OFF
	SET LINES 150
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
    	v_week_growth_string    VARCHAR2(10);
    	v_month_growth_string   VARCHAR2(10);
	
	------------------------------------------------------------------
	-- These are the values used to determine the alerting thresholds
	-- for the main select
	------------------------------------------------------------------
	
    	v_threshold_day           PLS_INTEGER:=90;
    	v_threshold_week          PLS_INTEGER:=50;
    	v_threshold_error         PLS_INTEGER:=95;
    	v_threshold_brown_trouser PLS_INTEGER:=98;

	BEGIN

        v_threshold_day := v_threshold_day - ${WEIGHTING};
        v_threshold_week := v_threshold_week + ${WEIGHTING};
        v_threshold_error := v_threshold_error - ${WEIGHTING}/2;
        v_threshold_brown_trouser := v_threshold_brown_trouser - ${WEIGHTING}/4;

--	DBMS_OUTPUT.PUT_LINE('v_threshold_day is: ' || TO_CHAR(v_threshold_day,'990'));
--	DBMS_OUTPUT.PUT_LINE('v_threshold_week is: ' || TO_CHAR(v_threshold_week,'990'));
--	DBMS_OUTPUT.PUT_LINE('v_threshold_error is: ' || TO_CHAR(v_threshold_error,'990'));
--	DBMS_OUTPUT.PUT_LINE('v_threshold_brown_trouser is: ' || TO_CHAR(v_threshold_brown_trouser,'990'));
	
	fileHandler := UTL_FILE.FOPEN('AMCHECK_TEMP', 'am_os_space_history.txt', 'W');
	
	DBMS_OUTPUT.PUT_LINE('Server               Mountpoint                               Today Yesterday Last Wk Last Mth Day Growth Wk Growth Mth Growth');
	DBMS_OUTPUT.PUT_LINE('-------------------- ---------------------------------------- ----- --------- ------- -------- ---------- --------- ----------');
	
	FOR c1 IN (
	WITH now_info AS
     	(SELECT  DISTINCT *
     	FROM (SELECT    s.server,
			d2.database_name,
                    	s.mountpoint,
                    	NVL(s.pctused,0) AS now_pctused,
                    	s.space_time     AS now_space_time,
                    	RANK() OVER (PARTITION BY s.server, s.mountpoint, d2.database_name ORDER BY s.server, s.mountpoint, d2.database_name, s.space_time DESC) AS my_rownum
            	FROM    amo.am_os_space s,
                    	am_server s1,
                    	am_server s2,
                    	am_database d1,
                    	am_database d2
            	WHERE   s.server = s2.physical_server_abbrev
            	AND     d1.server = s1.server
            	AND     d2.server = s2.server
            	AND     s1.physical_server_abbrev = s2.physical_server_abbrev
            	AND     d2.os_checks_ind = 'Y'
            	AND     d1.disabled <> 'Y'
            	AND     d2.disabled <> 'Y'
	    	AND     d1.database_name like '${DATABASE}'
	    	AND     d1.server like '${SERVER}'
                AND     s.space_time >= trunc(sysdate))
     	        WHERE   my_rownum = 1
     	        ORDER BY server, mountpoint, now_space_time, now_pctused),
        yesterday_info AS
	(SELECT *
     	FROM (SELECT    s.server,
			d2.database_name,
                    	s.mountpoint,
                    	NVL(s.pctused,0) AS yesterday_pctused,
                    	s.space_time     AS yesterday_space_time,
                    	RANK() OVER (PARTITION BY s.server, s.mountpoint, d2.database_name ORDER BY s.server, s.mountpoint, d2.database_name, s.space_time DESC) AS my_rownum
            	FROM    amo.am_os_space s,
                    	am_database d1,
			am_server s1,
			am_server s2,
                    	am_database d2
	    	WHERE   s.server = s2.physical_server_abbrev
		AND     d1.server = s1.server
		AND     d2.server = s2.server
                AND     s1.physical_server_abbrev = s2.physical_server_abbrev
		AND     d2.os_checks_ind = 'Y'
                AND     d1.disabled <> 'Y'
                AND     d2.disabled <> 'Y'
	    	AND     d1.database_name like '${DATABASE}'
	    	AND     d1.server like '${SERVER}'
            	AND     s.space_time < trunc(sysdate) AND s.space_time >= trunc(sysdate-7))
     	        WHERE   my_rownum = 1
            	ORDER BY server, mountpoint, yesterday_space_time, yesterday_pctused),
	lastweek_info AS
    	(SELECT *
     	FROM (SELECT    s.server,
			d2.database_name,
                    	s.mountpoint,
                    	NVL(s.pctused,0) AS lastweek_pctused,
                    	s.space_time     AS lastweek_space_time,
                    	RANK() OVER (PARTITION BY s.server, s.mountpoint, d2.database_name ORDER BY s.server, s.mountpoint, d2.database_name, s.space_time DESC) AS my_rownum
            	FROM    amo.am_os_space s,
                    	am_database d1,
			am_server s1,
			am_server s2,
                        am_database d2
	    	WHERE   s.server = s2.physical_server_abbrev
		AND     d1.server = s1.server
		AND     d2.server = s2.server
                AND     s1.physical_server_abbrev = s2.physical_server_abbrev
		AND     d2.os_checks_ind = 'Y'
                AND     d1.disabled <> 'Y'
                AND     d2.disabled <> 'Y'
	    	AND     d1.database_name like '${DATABASE}'
	    	AND     d1.server like '${SERVER}'
      		AND     s.space_time <= trunc(sysdate-7) AND s.space_time >= trunc(sysdate-13))
     	        WHERE   my_rownum = 1
            	ORDER BY server, mountpoint, lastweek_space_time, lastweek_pctused),
	lastmonth_info AS
    	(SELECT *
     	FROM (SELECT    s.server,
			d2.database_name,
                    	s.mountpoint,
                    	NVL(s.pctused,0) AS lastmonth_pctused,
                    	s.space_time     AS lastmonth_space_time,
                    	RANK() OVER (PARTITION BY s.server, s.mountpoint, d2.database_name ORDER BY s.server, s.mountpoint, d2.database_name, s.space_time DESC) AS my_rownum
            	FROM    amo.am_os_space s,
			am_server s1,
			am_server s2,
                    	am_database d1,
                        am_database d2
	    	WHERE   s.server = s2.physical_server_abbrev
		AND     d1.server = s1.server
		AND     d2.server = s2.server
                AND     s1.physical_server_abbrev = s2.physical_server_abbrev
		AND     d2.os_checks_ind = 'Y'
                AND     d1.disabled <> 'Y'
                AND     d2.disabled <> 'Y'
	    	AND     d1.server like '${SERVER}'
	    	AND     d1.database_name like '${DATABASE}' ${WHERE_ADDITION}
            	AND     s.space_time <= trunc(sysdate-13) AND s.space_time >= trunc(sysdate-62))
     	        WHERE   my_rownum = 1
            	ORDER BY server, mountpoint, lastmonth_space_time, lastmonth_pctused)
	SELECT DISTINCT server,
	database_name,
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
       	status,
        status_brief
	FROM (
	SELECT n.server,
       	n.mountpoint,
       	n.database_name,
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
       	(CASE 
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_brown_trouser) AND 
                     (n.now_pctused > l.lastweek_pctused) THEN 'Error: Weekly growth (Brown)'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_error) AND 
                     (n.now_pctused > l.lastweek_pctused +2 ) THEN 'Error: Weekly growth (Red)'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_week) AND 
                     ((100 - n.now_pctused) < (n.now_pctused - l.lastweek_pctused)) THEN 'Error: Weekly growth (Amber)'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (y.yesterday_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_day) AND 
                     ((100 - n.now_pctused) < (n.now_pctused - y.yesterday_pctused)) THEN 'Error: Daily growth (Amber)'
           	ELSE 'OK'
       	END) AS status,
       	(CASE 
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_brown_trouser) AND 
                     (n.now_pctused > l.lastweek_pctused) THEN '*ERROR'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_error) AND 
                     (n.now_pctused > l.lastweek_pctused +2 ) THEN '*ERROR*'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (l.lastweek_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_week) AND 
                     ((100 - n.now_pctused) < (n.now_pctused - l.lastweek_pctused)) THEN '*ERROR*'
		WHEN (n.now_pctused IS NOT NULL) AND 
                     (y.yesterday_pctused IS NOT NULL) AND 
                     (n.now_pctused > v_threshold_day) AND 
                     ((100 - n.now_pctused) < (n.now_pctused - y.yesterday_pctused)) THEN '*ERROR*'
           	ELSE ' '
       	END) AS status_brief
	FROM   now_info n,
       		yesterday_info y,
       		lastweek_info l,
       		lastmonth_info m
--	WHERE  n.server = y.server (+)
--	AND    n.mountpoint = y.mountpoint(+)
--	AND    n.server = l.server (+)
--	AND    n.mountpoint = l.mountpoint (+)
--	AND    n.server = m.server (+)
--	AND    n.mountpoint = m.mountpoint (+)
	WHERE  n.server = y.server 
	AND    n.mountpoint = y.mountpoint
	AND    n.database_name = y.database_name
	AND    n.server = l.server 
	AND    n.mountpoint = l.mountpoint 
	AND    n.database_name = l.database_name
	AND    n.server = m.server 
	AND    n.mountpoint = m.mountpoint 
	AND    n.database_name = m.database_name 
	)
	WHERE status like 'Error%' ${FORCE_STRING}
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
	
   	DBMS_OUTPUT.PUT_LINE(RPAD(c1.server,20) || ' ' ||
                        	RPAD(c1.mountpoint,40) || ' ' ||
                        	LPAD(c1.now_pctused_string,5) || ' ' ||
                        	LPAD(c1.yesterday_pctused_string,9) || ' ' ||
                        	LPAD(c1.lastweek_pctused_string,7) || ' ' ||
                        	LPAD(c1.lastmonth_pctused_string,8) || ' ' ||
                        	LPAD(v_day_growth_string,10) || ' ' ||
                        	LPAD(v_week_growth_string,9) || ' ' ||
                        	LPAD(v_month_growth_string,10) ||
                                ' ' || c1.status_brief);
    	v_rec_count:= v_rec_count + 1;
	
    	-- Dump out recent space records for each server+mountpoint should it be needed later (verbose mode)
    	-- I should probably make the code aware of the verbose indicator here as a future enhancement.
    	-- Note that BULK COLLECT will overwrite previous iterations so I'm writing to a file.
	
    	SELECT  server, mountpoint, pctused, sizek, usedk, availk, space_time 
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
                                      	RPAD(v_space(ix).mountpoint,40) || ' ' || 
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
	SPOOL OFF
	exit;
SQL700
fi	

if [[ -f ${TEMPFILE4} ]]
then
	ROWCOUNT=`cat ${TEMPFILE4} | sed '/^$/d' | wc -l`-4
else
	ROWCOUNT=0
fi

if [[ ${ROWCOUNT} -gt 0 ]] 
then
   	echo >> ${TEMPFILE4}
    	echo 'Note: If no yesterday/weekly/monthly data is found, values show are rounded to the nearest date to make comparisons possible' >> ${TEMPFILE4}
    	echo >> ${TEMPFILE4}
    	if [[ ${SEND_MAIL} == "M" ]] && [[ `grep -ic 'error' ${TEMPFILE4}` -gt 0 ]]
    	then
        	SEND_MAIL='Y'
    	fi
    	cat ${TEMPFILE4}
    	print " "
    	if [[ ${VERBOSE_IND} == "Y" ]] && [[ -f ${VERBOSE_FILE} ]]
    	then
        	print | tee -a ${TEMPFILE4}
        	print "Recent Daily High Water Marks" | tee -a ${TEMPFILE4}
        	print "==============================" | tee -a ${TEMPFILE4}
        	print | tee -a ${TEMPFILE4}
        	print "Server               Mountpoint                               PCUsed Date"  | tee -a ${TEMPFILE4}
        	print "-------------------- ---------------------------------------- ------ ---------------------" | tee -a ${TEMPFILE4}
        	cat ${VERBOSE_FILE} | tee -a ${TEMPFILE4}
    	fi
    	MAIL_TITLE="URGENT ${MAIL_TITLE}"
else
    	echo "No OS space alerts detected"
fi

if [[ ${REPORT_ONLY} == "N" ]]
then
   	##################################################
   	# Keep just over a month's data. Delete the rest.
   	##################################################
	sqlplus -s ${AMCHECK_TNS} <<- SQL800 > ${TEMPFILE5}
			set lines 300
			set feedback off
			set pages 0
			DELETE 
			FROM amo.am_os_space
			WHERE space_time < trunc(sysdate)-42;
			commit;
			exit;
SQL800
fi
	
if [[ ${SEND_MAIL} == "Y" ]]
then
  echo "Please see attached.." > ${MAIL_BUFFER}
#  f_mail Space_Summary_Alerts blue ${MAIL_RECIPIENT} "${TEMPFILE4}[courier]+${MAIL_BUFFER}[Arial]" ${MAIL_TITLE}
  f_mail Space_Summary_Alerts blue ${MAIL_RECIPIENT} "${TEMPFILE4}[courier]+${TEMPFILE4}[courier]" ${MAIL_TITLE}

fi

exit 0

