#!/bin/ksh
##########################################################################################
# Name             : am_datapump_export.ksh
# Author           : Tony Webb
# Created          : 25 Aug 2016 
# Type             : Korn shell script
# Version          : 040
# Parameters       : -m (mail default mailing list)
#                    -a alternate e-mail (separated by '+')
#                    -p n purge dumpfiles  older than 'n' days
#                    -s schemalist (separated by '+')
#                    dbname
#
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  Database name not supplied
#                    52  Database not running
#                    53  Database not open
#                    54  Database conenction problems (sqlplus)
#                    55  Directory AM_DATAPUMP_DIR not found
#                    56  No directory created for AM_DATAPUMP_DIR
#                    57  Directory does not exist or is not a directory
#                    58  Database not in ORATAB file
#
# Notes            : Run from the oracle account and export as 'internal'
#
# Prerequisites    : Oracle directory AM_DATAPUMP_DIR must exist
#                    OS directory /tmp/amchecks must exist
#                    OS directory ~oracle/amchecks must exist
#                    File ~oracle/amchecks/functions.ksh must exist
#                    File ~oracle/amchecks/.amcheck must exist (it only needs MAIL_RECIPIENT in it)
#                    File ~oracle/amchecks/am_datapump_export.ksh (this file!) must exist
#                    File ~oracle/amchecks/datapump.png must exist
#                    Local databases must have valid entries in the server ORATAB file
#
# Sample usage     : am_datapump_export.ksh -a "fred@flintstones.com+wilma@flintstones.com" -p 7 -s amu+amo PRDSID
#
#---------+----------+------------+-------------------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+-------------------------------------------------------
# 010     | 25/08/16 | T. Webb    | Original
# 020     | 30/08/16 | T. Webb    | Multiple and significant changes
# 030     | 31/08/16 | T. Webb    | Schema option added
# 040     | 15/09/16 | T. Webb    | List directory contents
##########################################################################################
#

# AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset DP_DIRECTORY
typeset DP_PATH
typeset DUMP_DIR
typeset EXP_TYPE
typeset FULL_IND='Y'
typeset TEMP_DIR=/tmp/amchecks
typeset TEMP_FILE1=${TEMP_DIR}/dptemp1
typeset TIMESTAMP=`date '+%y%m%d%H%M'`
typeset HASHLINE="###############################################################################################################"
typeset MAIL_FILE='${TEMP_DIR}/dp'
# MAIL_RECIPIENT should be set in the include file (.amcheck) otherwise override it here
typeset MAIL_TITLE
typeset ORATAB
typeset -i PURGE_DAYS=0
typeset RUNDATE=`date +'%d-%^b-%Y %H:%M:%S'`
typeset SCHEMAS
typeset -u SEND_MAIL='N'
typeset -u SID
typeset THISSCRIPTNAME=`basename $0`
typeset THIS_SERVER=`hostname -s`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -m -a e-mail_address (all in double-quotes and '+ separated) database -p n (purge dumps lder than 'n days') -s schemas (+ separated) database_name"

##################
# Local Functions
##################

function f_function1
{
    typeset PARAMS=$*
}

#######
# Main
#######

# Read environments for the morning checks
. ${AMCHECK_DIR}/.amcheck

# Read standard amchecks functions
. ${AMCHECK_DIR}/functions.ksh

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!

while getopts a:mp:s: o
do      case "$o" in
        a)      MAIL_RECIPIENT=`echo "${OPTARG}" | sed 's/\+/\,/g'`
                SEND_MAIL="Y";;
        m)      SEND_MAIL="Y";;
        p)      PURGE_DAYS="${OPTARG}";;
        s)      SCHEMAS="${OPTARG}"
		FULL_IND="N";;
        [?])    echo ${HASHLINE}
		echo -e "${THISSCRIPTNAME}: invalid parameters supplied \n${USAGE}"
                echo ${HASHLINE}
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 1 ]]
then
    echo ${HASHLINE}
    echo "Number of mandatory parameters supplied: $#. Please specify a local database to expdp"
    echo -e "${USAGE}"
    echo ${HASHLINE}
    exit 51
fi

SID=${1}

if [[ ${FULL_IND} == 'N' ]]
then
    SCHEMAS=`echo ${SCHEMAS} | sed 's/\+/\,/g'`
fi

if [[ `ps -elf | grep -w ora_smon_${SID} | wc -l` -lt 2 ]]
then
    echo ${HASHLINE}
    echo "Database smon process not found"
    echo -e "${USAGE}"
    echo ${HASHLINE}
    exit 52
fi

# Establish oratab depending on O/S
if [[ "`uname -a | cut -c1-3`" == "Sun" ]]
then
    ORATAB=/var/opt/oracle/oratab
else
    ORATAB=/etc/oratab
fi

export ORATAB

# Define ORACLE_HOME
if grep "^${SID}:" ${ORATAB} >/dev/null
then
  export ORACLE_HOME=`grep "^${SID}" ${ORATAB} | awk -F: '{print $2}'`
  export LD_LIBRARY_PATH=${ORACLE_HOME}/lib;
  export PATH=${PATH}:${ORACLE_HOME}/bin
else
  echo "Invalid SID"
  exit 58
fi

export ORACLE_SID=${SID}

# Validate database is here and responding

sqlplus -s '/ as sysdba' <<- SQL100 >${TEMP_DIR}/dp_instance_info
	SET PAGES 0
	SET FEEDBACK OFF
	SET LINES 130
	COL status FORMAT a50
	SPOOL ${TEMP_DIR}/exp${SID}.lst
	SELECT status FROM v\$instance WHERE instance_name='${SID}';
	spool off
        exit;
SQL100
if [[ $? -eq 0 ]]
then
    cat ${TEMP_DIR}/exp${SID}.lst | sed '/^$/d' | while read LINE
    do
        if [[ ${LINE} != "OPEN" ]]
        then
            echo ${HASHLINE}
            echo "Please specify a local (and open) database to expdp"
            echo -e "${USAGE}"
            echo ${HASHLINE}
            exit 53
        fi
    done
else
    echo ${HASHLINE}
    echo "Problems connecting to the specified database - ${SID}"
    echo -e "${USAGE}"
    echo ${HASHLINE}
    exit 54
fi

###############################################
# Need to find out where we are exporting to!
###############################################
DUMP_DIR=`sqlplus -s '/ as sysdba' <<- SQL200
	set pages 0
	set feedback off
        SELECT directory_name || '+' || directory_path FROM dba_directories WHERE directory_name = 'AM_DATAPUMP_DIR';
	exit;
SQL200`
if [[ $? -ne 0 ]]
then
    echo ${HASHLINE}
    echo "Directory AM_DATAPUMP_DIR not found. Please create for database - ${SID}"
    echo ${HASHLINE}
    exit 55
else
    typeset DP_PATH=${DUMP_DIR##*+}
fi

if [[ -z ${DP_PATH} ]]
then
    echo ${HASHLINE}
    echo "No directory created for AM_DATAPUMP_DIR"
    echo ${HASHLINE}
    exit 56
elif [[ ! -d ${DP_PATH} ]]
then
    echo ${HASHLINE}
    echo "Directory ${DP_PATH} does not exist or is not a directory"
    echo ${HASHLINE}
    exit 57
fi

if [[ ${FULL_IND} == 'Y' ]]
then
    EXP_TYPE='FULL'
    MAIL_TITLE="Datapump (FULL) on database ${SID} running on ${THIS_SERVER} at ${RUNDATE}"
else
    EXP_TYPE='SCHEMAS'
    MAIL_TITLE="Datapump (SCHEMAS=${SCHEMAS}) on database ${SID} running on ${THIS_SERVER} at ${RUNDATE}"
fi
DUMP_FILE=EXP_${EXP_TYPE}_${SID}_${TIMESTAMP}.expdp
LOG_FILE=EXP_${EXP_TYPE}_${SID}_${TIMESTAMP}.log

################
# Purge section
################

echo '' > ${TEMP_FILE1}
if [[ ${PURGE_DAYS} -gt 0 ]]
then
    echo 'Determining which files will be purged (files in '${DP_PATH}' that are over '${PURGE_DAYS}' days old)...' > ${TEMP_FILE1}
    echo '' >> ${TEMP_FILE1}
    find ${DP_PATH} -maxdepth 1 -name 'EXP_'${EXP_TYPE}'_'${SID}'_*.*' -mtime +${PURGE_DAYS} -exec ls -l {} \; | tee -a ${TEMP_FILE1} 2>&1
    echo '' | tee -a ${TEMP_FILE1}
    find ${DP_PATH} -maxdepth 1 -name 'EXP_'${EXP_TYPE}'_'${SID}'_*.*' -mtime +${PURGE_DAYS} -exec rm -v -f {} \; | sed 's/\‘//g' | sed 's/\’//g' | tee -a ${TEMP_FILE1} 2>&1
    echo '' >> ${TEMP_FILE1}
fi

###########################
# The Actual expdp command
###########################
if [[ ${FULL_IND} == 'Y' ]]
then
    ${ORACLE_HOME}/bin/expdp \"/ as sysdba\" DIRECTORY=AM_DATAPUMP_DIR DUMPFILE=${DUMP_FILE} FULL=Y FLASHBACK_TIME=systimestamp LOGFILE=${LOG_FILE} 
else
    ${ORACLE_HOME}/bin/expdp \"/ as sysdba\" DIRECTORY=AM_DATAPUMP_DIR DUMPFILE=${DUMP_FILE} SCHEMAS=${SCHEMAS} FLASHBACK_TIME=systimestamp LOGFILE=${LOG_FILE} 
fi

if [[ $? -ne 0 ]]
then
    echo ${HASHLINE}
    echo "Problems running export. Please check the log - ${TEMP_DIR}/${LOG_FILE} (if it exists)"
    MAIL_TITLE="ERROR: ${MAIL_TITLE}"
    echo ${HASHLINE}
else
    rm -f ${TEMP_DIR}/${LOG_FILE}
fi

echo 'Current space usage and file listing for the chosen mountpoint (for '${DP_PATH}')' | tee -a ${TEMP_FILE1}
echo '' | tee -a ${TEMP_FILE1}
df -Ph ${DP_PATH} | tee -a ${TEMP_FILE1}
echo '' | tee -a ${TEMP_FILE1}
ls -lartR ${DP_PATH} | tee -a ${TEMP_FILE1}
echo '' | tee -a ${TEMP_FILE1}

if [[ ! -f ${DP_PATH}/${LOG_FILE} ]]
then
    echo "No log file created for this export..." | tee -a ${DP_PATH}/${LOG_FILE}
fi

if [[ ${SEND_MAIL} == 'Y' ]]
then
    echo "Datapump log below. N.B. See the attachment for a more detailed log including rowcounts." >> ${TEMP_FILE1}
    grep -v 'exported' ${DP_PATH}/${LOG_FILE} | grep -v 'Processing object type' >> ${TEMP_FILE1}
    f_mail ~/amchecks/datapump.png "#702EBF" ${MAIL_RECIPIENT} "${DP_PATH}/${LOG_FILE}+${TEMP_FILE1}" "${MAIL_TITLE}"
fi

exit 0

