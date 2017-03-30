#!/bin/ksh
##################################################################################
# Name             : metric.ksh
# Author           : Tony Webb
# Created          : 02 June 2015
# Type             : Korn shell script
# Version          : 010
# Parameters       : -a  address (alternative e-mail address)
#                    -d  database 
#                    -m  (mail)
# Returns          :  0  Success
#                    50  Wrong parameters
#
# Notes            : 
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 02/06/15 | T. Webb    | Original
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environments for the morning checks
. ${AMCHECK_DIR}/.amcheck
# Read standard amchecks functions
. ${AMCHECK_DIR}/functions.ksh

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -c (cron mode) -m (mail) -d database (defaults to all)"

typeset CRON_MODE='N'
typeset DATABASE
typeset EXTERNAL_DIR="${AMCHECK_DIR}/external_tables"
typeset LANG=en_GB
typeset LINE
typeset MAIL_BUFFER="${TEMP_DIR}/metrics_mail"

typeset MAIL_TITLE='Database Metrics'
typeset SEND_MAIL='N'
typeset TEMPFILE1="${TEMP_DIR}/metrics.lst"
typeset TEMPFILE2="${TEMP_DIR}/metrics2.lst"
typeset TEMPFILE3="${TEMP_DIR}/metrics3.lst"
typeset TEMPFILE4="${TEMP_DIR}/metrics4.lst"
typeset TNS_ADMIN="${TEMP_DIR}"
export TNS_ADMIN

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

    print "Processing ${UC_SID}"

    sqlplus -s ${CONNECT}\@${SID} <<- SQL100 > ${TEMPFILE1}
	set pages 0
	set lines 200
	set feedback off
	SELECT  LOWER(v.host_name) || ', ' || 
		TO_CHAR(sysdate,'DD-MM-YY@HH24:MI:SS') || ' ' ||
		REPLACE(m.metric,' ','_') || ' ' || m.value
	FROM    (SELECT 'WAIT: SINGLE BLOCK READ' AS metric, 
			TO_CHAR(SUM(DECODE(event,'db file sequential read',total_waits,0))) AS value 
		FROM V\$system_event 
		WHERE event NOT IN ('SQL*Net message from client', 'SQL*Net more data from client', 'pmon timer', 'rdbms ipc message', 'rdbms ipc reply', 'smon timer') 
		UNION ALL 
		SELECT 'STAT: BUFFER HIT RATIO', TO_CHAR(1-(SUM(DECODE(name,'physical reads',value,0))/(SUM(DECODE(name,'db block gets',value,0)) + (SUM(DECODE(name,'consistent gets',value,0))))),'990.9999999999')
		FROM v\$sysstat
		UNION ALL
		SELECT 'WAIT: SQLNET WAITS', TO_CHAR(SUM(DECODE(event,'SQL*Net message to client',total_waits,'SQL*Net message to dblink',total_waits, 
			'SQL*Net more data to client',total_waits,'SQL*Net more data to dblink',total_waits,'SQL*Net break/reset to client',total_waits, 
			'SQL*Net break/reset to dblink',total_waits,0))) 
		FROM V\$system_event 
		WHERE event NOT IN ('SQL*Net message from client','SQL*Net more data from client','pmon timer', 'rdbms ipc message','rdbms ipc reply', 'smon timer') 
		UNION ALL 
		SELECT 'WAIT: OTHER WAITS', TO_CHAR(SUM(DECODE(event,'control file sequential read',0,'control file single write',0,'control file parallel write',0,' 
			db file sequential read',0,'db file scattered read',0,'direct path read',0,'file identify',0,'file open',0,'SQL*Net message to client',0, 
			'SQL*Net message to dblink',0, 'SQL*Net more data to client',0,'SQL*Net more data to dblink',0, 'SQL*Net break/reset to client',0, 
			'SQL*Net break/reset to dblink',0, 'log file single write',0,'log file parallel write',0,total_waits))) 
		FROM V\$system_event 
		WHERE event NOT IN ('SQL*Net message from client', 'SQL*Net more data from client', 'pmon timer', 'rdbms ipc message',  'rdbms ipc reply', 'smon timer') 
		UNION ALL 
		SELECT 'WAIT: MULTIBLOCK READ', TO_CHAR(SUM(DECODE(event,'db file scattered read',total_waits,0))) 
		FROM V\$system_event 
		WHERE event NOT IN ('SQL*Net message from client','SQL*Net more data from client','pmon timer', 'rdbms ipc message', 'rdbms ipc reply', 'smon timer') 
		UNION ALL 
		SELECT 'WAIT: LOGWRITE', TO_CHAR(SUM(DECODE(event,'log file single write',total_waits, 'log file parallel write',total_waits,0))) LogWrite 
		FROM V\$system_event 
		WHERE event NOT IN ('SQL*Net message from client', 'SQL*Net more data from client', 'pmon timer', 'rdbms ipc message', 'rdbms ipc reply', 'smon timer') 
		UNION ALL 
		SELECT 'WAIT: IO WAITS', TO_CHAR(SUM(DECODE(event,'file identify',total_waits, 'file open',total_waits,0))) 
		FROM V\$system_event 
		WHERE event NOT IN ('SQL*Net message from client', 'SQL*Net more data from client', 'pmon timer', 'rdbms ipc message', 'rdbms ipc reply', 'smon timer') 
		UNION ALL 
		SELECT 'WAIT: CONTROLFILE IO ', TO_CHAR(SUM(DECODE(event,'control file sequential read', total_waits, 'control file single write', total_waits, 
			'control file parallel write',total_waits,0))) ControlFileIO 
		FROM V\$system_event WHERE event NOT IN ( 'SQL*Net message from client', 'SQL*Net more data from client', 'pmon timer', 'rdbms ipc message', 
			'rdbms ipc reply', 'smon timer')
		UNION ALL 
		SELECT 'WAIT: DIRECTPATH READ', TO_CHAR(SUM(DECODE(event,'direct path read',total_waits,0))) 
		FROM V\$system_event 
		WHERE event NOT IN ('SQL*Net message from ', 'SQL*Net more data from client','pmon timer', 'rdbms ipc message', 'rdbms ipc reply', 'smon timer') 
		UNION ALL 
		SELECT 'SESSIONS: HIGHWATER',  TO_CHAR(sessions_highwater) 
		FROM   v\$license 
		UNION ALL SELECT 'SESSIONS: CURRENT', TO_CHAR(count(username)) 
		FROM v\$session 
		WHERE username IS NOT NULL 
		UNION ALL SELECT 'STAT: ' || UPPER(name), TO_CHAR(value) 
		FROM V\$SYSSTAT 
		WHERE name IN ( 'db block gets', 'consistent gets', 'physical reads', 'physical reads direct', 'physical writes direct', 'table scans (direct read)', 
			'table scans (long tables)', 'table scans (rowid ranges)', 'table scans (short tables)', 'db_block_changes', 'redo writes')
		UNION ALL
		SELECT 'MEMORY: PGA', TO_CHAR(ROUND(value/1024/1024/1024,3)) FROM v\$pgastat WHERE name = 'total PGA allocated'
		UNION ALL
		SELECT 'MEMORY: SGA', TO_CHAR(ROUND(SUM(bytes)/1024/1024/1024,3)) FROM v\$sgastat
                ) m,
		v\$instance v
	ORDER BY 1;
    	exit;
SQL100

    cat ${TEMPFILE1} | sed '/^$/d' | grep ', ' | while read LINE
    do
        set ${LINE}
        SERVER=${1}
        # Next bit is to put back the comma that the cut removes when it strips out the domain from the server name
        if [[ `echo ${SERVER} | grep -c '\.'` -gt 0 ]]
        then
            SERVER=`echo ${SERVER} | cut -d'.' -f1`
        fi
        SPACE_TIME=`echo ${2} | sed 's/@/ /g'`
        METRIC=`echo ${3} | sed 's/_/ /g'`
        VALUE=${4}

        print -- "${UC_SID}, ${SERVER}, ${SPACE_TIME}, ${METRIC}, ${VALUE}" >> ${EXTERNAL_DIR}/am_metric_load.dbf
    done
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

while getopts a:d:m o
do      case "$o" in
        a)      MAIL_RECIPIENT="${OPTARG}"  
	        SEND_MAIL="Y";;
        d)      DATABASE="${OPTARG}"
		MAIL_TITLE="${MAIL_TITLE} for ${DATABASE}";;
	m)      SEND_MAIL="Y";;
        [?])    print -- "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 0 ]]
then
   if [[ ${CRON_MODE} = 'Y' ]]
   then 
        print -- "Error - please do not specify positional parameters."
   else
        f_redprint "Error - please do not specify positional parameters"
   fi
   exit 50
fi

EXTERNAL_DIR=~oracle/amchecks/external_tables
    
if [[ ! -d ${EXTERNAL_DIR} ]]
then
   mkdir ${EXTERNAL_DIR}
fi

TEMPFILE4="${EXTERNAL_DIR}/am_metric_check.dbf"
# Header. External table definition needs to 'skip 2'
print -- "DATABASE_NAME,  SERVER, SPACE_TIME, METRIC, VALUE" > ${EXTERNAL_DIR}/am_metric_load.dbf
print -- "-------------------------------------------------------------------------------------------" >> ${EXTERNAL_DIR}/am_metric_load.dbf

if [[ ! -z ${DATABASE} ]]
then
    f_run ${DATABASE}
else
    DATABASE='%'
	sqlplus -s ${AMCHECK_TNS} <<- SQL500 > ${TEMPFILE2}
	SET PAGES 0
	SET FEEDBACK OFF
	SELECT database_name FROM amo.am_database WHERE disabled <> 'Y' ORDER BY 1;
	exit;
SQL500
    cat ${TEMPFILE2} | sed '/^$/d' | while read SID
    do
        f_run ${SID}
    done
fi

###############################################################################
# Metrics have been gathered and dumped into an external table. 
# Load these into a 'proper' history table now, purging data over a week old
# and 'rolling up' older data into a rollup table.
#
# Then run a check on the history table to highlight any issues.
#
###############################################################################

	sqlplus -s ${AMCHECK_TNS} <<- SQL600 > ${TEMPFILE3}
	ALTER SESSION SET NLS_DATE_FORMAT='DD-MM-YY HH24:MI:SS';
	INSERT INTO amo.am_metric_hist
	(database_name, server, space_time, metric, value)
	SELECT database_name, server, space_time, metric, value
	FROM amo.am_metric_load;
	SPOOL ${TEMPFILE4}
	start ${AMCHECK_DIR}/metric_check.sql ${DATABASE}
	SPOOL OFF
	exit;
SQL600

cat ${TEMPFILE4}

if [[ ${SEND_MAIL} == "Y" ]]
then
  echo "Please see attached.." > ${MAIL_BUFFER}
#  f_mail Metrics blue ${MAIL_RECIPIENT} "${TEMPFILE4}[courier]+${MAIL_BUFFER}[Arial]" "wibble"
f_mail Metrics blue ${MAIL_RECIPIENT} "${TEMPFILE4}[courier]+${MAIL_BUFFER}[Arial]" ${MAIL_TITLE}
fi
exit 0

