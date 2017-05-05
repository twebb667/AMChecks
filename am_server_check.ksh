#!/bin/ksh
##################################################################################
# Name             : am_server_check.ksh
# Author           : Tony Webb
# Created          : 01 March 2017
# Type             : Korn shell script
# Version          : 020
# Parameters       :
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  Environment problems
#                    54  Missing files
#
# Notes            : 
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 01/03/17 | T. Webb    | Original
# 020     | 05/05/17 | T. Webb    | Added 'LOWER' function to query.
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environment variables for the morning checks
. ${AMCHECK_DIR}/.amcheck

# Read standard amchecks functions
. ${AMCHECK_DIR}/functions.ksh

typeset -u SID
typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} SID"
typeset -l HOST
typeset TEMPFILE1="${TEMP_DIR}/am_server_check_1.lst"
typeset TNSNAMES
#typeset TNS_ADMIN=${AMCHECK_DIR}
# TNSPING location Can only be set once we know ORACLE_HOME..
typeset TNSPING=${ORACLE_HOME}/bin/tnsping

#######
# Main
#######

if [[ $# -ne 1 ]]
then
    echo "${USAGE}: Please supply a database SID or SERVICE_NAME"
    exit 50
fi

SID=$1

HOST=`${TNSPING} ${SID} | tr "[:lower:]" "[:upper:]" | sed '/SID/s//SERVICE_NAME/' | perl -ne '$h_sid="$1" if /\(HOST\s=\s([^)]+)\).+\(SERVICE_NAME\s=\s([^)]+)/;print "$h_sid\n" if /\((\d+)\s*MSEC\)/;' | cut -d'.' -f1`

sqlplus -s ${AMCHECK_TNS} <<- SQL100 > ${TEMPFILE1}
	SET PAGES 0 
	SET FEEDBACK OFF
	SELECT physical_server FROM amo.am_server WHERE LOWER(server) = '${HOST}';
	exit;
SQL100
        ACTUAL_HOST=`cat ${TEMPFILE1}`

echo
echo "   SID=${SID} HOST=${HOST} ACTUAL_HOST=${ACTUAL_HOST}"
echo

