#!/bin/ksh
##################################################################################
# Name             : purge_oracle_logs.ksh
# Author           : Tony Webb
# Created          : 23 May 2016
# Type             : Korn shell script
# Version          : 030
# Parameters       : 
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  environment problems
# Notes            
# ~~~~~~
# There is a dependency on ~oracle/amchecks/.amcheck in this script.
# This could be removed if some other way of setting ORACLE_HOME, PATH and
# LD_LIBRARY_PATH is used.
#
# There is also a dependency on logrotate being installed. 
# This script will fail on pre Oracle 11.1 databases too.
#
# Note that optional parameters will aply to ALL databases running on a host.
# The -t parameter will apply to all purges, not just trace file purging.
#
# example cron:
#
# 30 0 * * * ksh -c '/home/oracle/amchecks/purge_oracle_logs.ksh -a3 -t36000 1> /tmp/amchecks/purge.log  2>&1'
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 23/05/16 | T. Webb    | Original
# 020     | 25/05/16 | T. Webb    | More information to the screen
# 030     | 25/05/16 | T. Webb    | Optional parameters (-a -t)
##################################################################################
.  ~oracle/amchecks/.amcheck

typeset TEMP_DIR=/tmp/orapurge
typeset HOUR=`date +"%H"`

typeset AUDIT_DAYS=7 # quite aggresive - only keep 7 days of aud files.
typeset AUDIT_IND='N'
typeset ORATAB='/etc/oratab'
typeset THIS_SERVER=`uname -a | cut -d' ' -f2 | cut -d'.' -f1`
typeset TEMPFILE1="${TEMP_DIR}/purge_oracle_logs.${HOUR}.lst"
typeset TEMPFILE2="${TEMP_DIR}/purge_oracle_logs2.${HOUR}.lst"
typeset TEMPFILE3="${TEMP_DIR}/purge_oracle_logs3.${HOUR}.lst"
typeset THISSCRIPTNAME=`basename $0`
typeset TIMESTAMP=`date +"%a%d%b%Y%H:%M:%S"`
typeset ADR_IND='N'
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -a days -t days" 

############
# Functions
############

function f_adr_stuff
{
    typeset PURGE_STRING="purge"
    if [[ ${ADR_IND} == "Y" ]]
    then 
        PURGE_STRING="purge -age ${ADR_MINS}"
    fi

    adrci exec="show homes"|grep -v ':' | while read ADRHOME
    do
        adrci exec="set home ${ADRHOME}; ${PURGE_STRING}; show control"
    done
}

function f_listener_stuff
{
    typeset LOG=$1
    typeset DIR=`dirname ${LOG}`
    typeset LOGSHORT=`basename ${LOG}`
    
    CONF=${TEMP_DIR}/${LOGSHORT}.conf
    cat <<- LOGR02 >${CONF}
	${LOG} {
	notifempty
	size 20M
	copytruncate
	dateext
	missingok
	rotate 20
	compress
	}
	LOGR02
 
    ls -l ${DIR}/listen* 2>/dev/null
    echo
    logrotate -s ${TEMP_DIR}/${LOGSHORT} -f ${CONF}
}

function f_db_stuff
{
    export ORAENV_ASK=NO
    typeset DB=$1

    DBNAME=`echo ${DB} | cut -d ':' -f1`
    ORACLE_HOME=`echo ${DB} | cut -d ':' -f2`

    echo
    echo "Processing ${DBNAME} running from ${ORACLE_HOME}"
    export ORACLE_SID=${DBNAME}
    . oraenv >/dev/null 

    sqlplus -s / as sysdba <<- SQL01 >> ${TEMPFILE1}
	SET PAGES 0
	SET FEEDBACK OFF
	SELECT DISTINCT 	'${DBNAME} Short Policy is ' || shortp_policy || ' days' AS short_policy, 
				'${DBNAME} Long Policy is ' || longp_policy || ' days' AS long_policy
	FROM v\$diag_adr_control;
	exit;
	SQL01

    sqlplus -s / as sysdba <<- SQL02 > ${TEMPFILE2}
	SET PAGES 0
	SET FEEDBACK OFF
	SELECT value || '/alert_' || instance_name || '.log'
	FROM  v\$parameter,
      	v\$instance
	WHERE name='background_dump_dest';
	exit;
	SQL02

    if [[ $? -eq 0 ]]
    then
        ALERTLOG=`cat ${TEMPFILE2}`
        export CONF=${TEMP_DIR}/${DBNAME}_alert.conf
        export DIR=`dirname ${ALERTLOG}`
    
        typeset TRACES=`ls -1 ${DIR}/*.tr* 2>/dev/null | wc -l`
        echo "Trace file count: ${TRACES}"
	ls -l  ${DIR}/*aler* 2>/dev/null

    	cat <<- LOGR01 >${CONF}
    	${ALERTLOG} {
	notifempty
	size 20M
	copytruncate
	dateext
	missingok
	rotate 20
	compress
	}
	LOGR01
 
        logrotate -s ${TEMP_DIR}/log_rotate_status${DBNAME}_alert -f ${CONF}
    else
        echo "Error connecting to database ${DBNAME} in ${ORACLE_HOME}"
    fi

    sqlplus -s / as sysdba <<- SQL03 > ${TEMPFILE3}
	SET PAGES 0
	SET FEEDBACK OFF
	SELECT value 
	FROM  v\$parameter
	WHERE name='audit_file_dest';
	exit;
	SQL03
    
    if [[ $? -eq 0 ]]
    then
        typeset AUDITDIR=`cat ${TEMPFILE3}`
   
        echo "Debug Audit DIR is ${AUDITDIR}"
        typeset AUDITS=`ls -1 ${AUDITDIR}/*.aud 2>/dev/null | wc -l`
        echo "Audit file count: ${AUDITS}"
	find ${AUDITDIR} -name '*.aud' -mtime +${AUDIT_DAYS} -exec rm -v -f {} \;
    fi

}

#######
# Main
#######

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!
while getopts a:t: o
do      case "$o" in
        a)      AUDIT_DAYS=${OPTARG}
                AUDIT_IND="Y";;
        t)      ADR_MINS=${OPTARG}
                ADR_IND="Y";;
        [?])    print -- "${THISSCRIPTNAME}: invalid parameters supplied \n${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 0 ]]
then
   print "ERROR: Please do not specify any positional parameters"
   exit 50
fi

rm -f ${TEMPFILE1}

if [[ ! -d ${TEMP_DIR} ]]
then
    mkdir -p ${TEMP_DIR} 
fi

echo "ADR Details:"
echo "============"
f_adr_stuff

if [[ `cat ${ORATAB} | wc -l` -gt 0 ]]
then
    echo "Alert log, Trace File And Audit File Details:"
    echo "============================================="
    cat ${ORATAB} | grep -v '#' | grep Y\$ | while read LINE
    do
        f_db_stuff "${LINE}"
    done
else
    echo "ERROR: No ${ORATAB} file detected!"
    exit 51
fi

echo 
echo "Listener Files:"
echo "==============="
for LOG in `find ${ORACLE_BASE} -name *listener*log -type f`
do
    f_listener_stuff ${LOG}
done

echo "ADR Policy Details:"
echo "==================="
cat ${TEMPFILE1}

exit 0

