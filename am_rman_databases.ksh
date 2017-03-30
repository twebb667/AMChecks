#!/bin/ksh
##################################################################################
# Name             : am_rman_databases.ksh.ksh
# Author           : Tony Webb
# Created          : 11 April 2016
# Type             : Korn shell script
# Version          : 010
# Parameters       : 
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  Environment problems
#                    54  Missing files
#
# Notes            : This only nends to be help locally (and added to cron) 
#                    on the host for the RMAN catalog
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 11/04/16 | T. Webb    | Original
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environment variables for the morning checks
. ${AMCHECK_DIR}/.amcheck

# Read standard amchecks functions
. ${AMCHECK_DIR}/functions.ksh

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME}"
typeset -l HOST
typeset LANG=en_GB
typeset TEMPFILE1="${TEMP_DIR}/am_rman_databases.lst"
typeset THIS_SERVER=`hostname -s`
typeset TNS_ADMIN=${TEMP_DIR}

sqlplus -s -L ${CONNECT}\@${ORACLE_SID} <<- SQL10 >${TEMPFILE1} 2>&1
set pages 0
set feedback off
SELECT DISTINCT name from rman.rc_database;
exit;
SQL10

exit 0

