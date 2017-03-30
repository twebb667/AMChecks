#!/bin/ksh
##################################################################################
# Name             : parse_alertlog.ksh
# Author           : Tony Webb
# Created          : 10 June 2014
# Type             : Korn shell script
# Version          : 020
# Parameters       : -l line        (read from line number specified)
#                    -d days
#                    -a show all, not just errors
#                    local_database 
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  environment problems
#                    54  Missing files
#
# Notes            : 
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 10/06/14 | T. Webb    | Original
# 020     | 17/06/14 | T. Webb    | Functions moved to separate file
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environments for the morning checks
source ${AMCHECK_DIR}/.amcheck

typeset SCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${SCRIPTNAME} -l lineno -d days -a (all messages) database"

typeset ALERT_DIR
typeset ALERT_LOG
typeset ALL_IND='N'
typeset -i DAYS=0
typeset -i FILESIZE
typeset GREP_STRING=' '
typeset LANG=en_GB
typeset -i LINE_COUNT=0
typeset -i LINE_NO=0
typeset PRINT_STRING
typeset SEARCH_DAY
typeset -i START_LINE_NO
typeset TEMP_FILE1="${TEMP_DIR}/${SCRIPTNAME}.lst"
typeset TEMP_FILE2=$${TEMP_DIR}/${SCRIPTNAME}2.tmp"
typeset TNSNAMES
typeset TNS_ADMIN=${AMCHECK_DIR}
export TNS_ADMIN

# Read standard amchecks functions
source ${AMCHECK_DIR}/functions.ksh

#######
# Main
#######

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!
while getopts ad:l: o
do      case "$o" in
        a)      ALL_IND="Y";;
        d)      DAYS=${OPTARG};;
        l)      LINE_NO=${OPTARG};;
        [?])    f_redprint ${SCRIPTNAME}: invalid parameters supplied - ${USAGE}
                exit 50;;
        esac
done

if [[ ${LINE_NO} -gt 0 ]] && [[ ${DAYS} -gt 0 ]]
then
    f_redprint ${SCRIPTNAME}: You may not specify both line and days as limiters - ${USAGE}
    exit 50
fi

shift `expr ${OPTIND} - 1`

#############################################
# Check that database name has been supplied
#############################################

if [[ $# -ne 1 ]]
then
    f_redprint ${SCRIPTNAME}: invalid parameters supplied - ${USAGE}
    exit 50
fi

export ORACLE_SID=$1

#########################
# Create TNS environment 
#########################
if [[ -f ${AMCHECK_DIR}/tnsnames.ora ]]
then
    TNSNAMES=${AMCHECK_DIR}/amchecks/tnsnames.ora
else
    f_redprint "Expected TNSNAMES file(s) not found. Aborting."
    exit 51
fi

mkdir ${TNS_ADMIN} 2>/dev/null
cp ${TNSNAMES} ${TNS_ADMIN}/.

############################
# Get location of alert log
############################
sqlplus -s ${CONNECT}\@${ORACLE_SID} <<- SQL100 > ${TEMP_FILE1}
set pages 0
select value from v\$parameter where name = 'background_dump_dest';
exit;
SQL100

ALERT_DIR=`cat ${TEMP_FILE1} | sed '/^$/d'`
if [[ ! -d ${ALERT_DIR} ]]
then
    f_redprint 'Directory ${ALERT_DIR} not found.'
    exit 54
fi

ALERT_LOG=${ALERT_DIR}/alert_${ORACLE_SID}.log
if [[ ! -f ${ALERT_LOG} ]]
then
    f_redprint 'Alertlog ${ALERT_LOG} not found.'
    exit 54
fi

if [[ ${ALL_IND} = 'N' ]]
then
   GREP_STRING=" | grep -iE 'ORA-|TNS-|TWO-TASK|FAILED' ${FILE} | grep -v '(WARN)' | sort | uniq -c"
   PRINT_STRING="Showing errors only for "
else
   PRINT_STRING="Showing all entries for "
fi

if [[ ${DAYS} -gt 0 ]]
then
    f_greenstar ${PRINT_STRING} file ${ALERT_LOG} for the last ${DAYS} days
    SEARCH_DAY=`date -d -${DAYS}days +"%a %b %d"`
    START_LINE_NO=`grep -n -m1 "${SEARCH_DAY}" ${ALERT_LOG} | cut -d':' -f1`
    eval tail -n +${START_LINE_NO} ${ALERT_LOG} ${GREP_STRING} > ${TEMP_FILE2}
    cat ${TEMP_FILE2} 
else
    f_greenstar ${PRINT_STRING} file ${ALERT_LOG} for the last ${LINE_NO} lines
    eval tail --lines=${LINE_NO} ${ALERT_LOG} ${GREP_STRING} > ${TEMP_FILE2} 
    cat ${TEMP_FILE2} 
fi
LINE_COUNT=`wc -l ${TEMP_FILE2} | cut -d' ' -f1`
f_greenprint \(${LINE_COUNT} lines\)

exit 0

