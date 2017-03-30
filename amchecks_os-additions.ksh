#!/bin/ksh
##################################################################################
# Name             : os_space_check.ksh
# Author           : Tony Webb
# Created          : 12 January 2016
# Type             : Korn shell script
# Version          : 010
# Parameters       : -c  (cron mode)
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  environment problems
#                    54  Missing files
#
# Notes            
# ~~~~~~
# Run this on every server where you want to report OS space usage.
# For tis to work, add a daily cron to run this and also ensure that the external
# table exists, owned by amu:
#
# CREATE TABLE AM_OS_SPACE_LOAD 
# (
#    SERVER          VARCHAR2(30 CHAR),
#    FILESYSTEM      VARCHAR2(200 CHAR),
#    SIZEK           NUMBER(10),
#    USEDK           NUMBER(10),
#    AVAILK          NUMBER(10),
#    PCTUSED         NUMBER(3),
#    MOUNTPOINT      VARCHAR2(200 CHAR),
#    DF_DATE_CHAR    VARCHAR2(10)
# ) 
# ORGANIZATION EXTERNAL 
# ( 
#  TYPE ORACLE_LOADER 
#  DEFAULT DIRECTORY AMCHECK_DIR 
#  ACCESS PARAMETERS 
#  ( 
#    RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
#             SKIP 0 FIELDS TERMINATED BY ', ' MISSING FIELD VALUES ARE NULL 
#  ) 
#  LOCATION 
#  ( 
#    AMCHECK_DIR: 'am_os_space_load.dbf' 
#  ) 
# ) 
# REJECT LIMIT UNLIMITED;
#
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 12/01/16 | T. Webb    | Original
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

typeset CRON_MODE='Y'
typeset DF_DATE=`date +%d/%m/%y`
typeset THIS_SERVER=`hostname -s`
typeset TEMPFILE1="${TEMP_DIR}/temp_am_os_space_load"
typeset TEMPFILE2="${TEMP_DIR}/os_space_alerts"
typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -c (running from cron)" 

#######
# Main
#######

# Include additional info for the morning checks
. ${AMCHECK_DIR}/.amcheck
. ${AMCHECK_DIR}/functions.ksh

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!
# Note that 'g' will be permitted (assume caller wants a report in gig and was unfamiliar with parameters)

while getopts c o
do      case "$o" in
        c)      CRON_MODE="Y";;
        [?])    print "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 0 ]]
then
   if [[ ${CRON_MODE} = 'Y' ]]
   then 
        print "Error please do not specify any positional parameters"
   else
        f_redprint "Error please do not specify any positional parameters"
   fi
   exit 50
fi

EXTERNAL_DIR=`sqlplus -s -L ${CONNECT}\@${ORACLE_SID} <<- SQL10
	set pages 0
	set feedback off
	SELECT directory_path FROM dba_directories where owner = 'SYS' and directory_name = 'AMCHECK_DIR';
	exit;
SQL10`

if [[ ! -d ${EXTERNAL_DIR} ]]
then
    mkdir ${EXTERNAL_DIR}
fi

rm -f ${EXTERNAL_DIR}/am_os_space_load.dbf

#########################################################
# Populate the flatfile/datafile for the external tables
#########################################################
df -lkP | awk '{  
          if ( NR == 1 ) { next }  
          if ( NF == 6 ) { print }  
          if ( NF == 5 ) { next }  
          if ( NF == 1 ) {  
                getline record;  
                $0 = $0 record  
                print $0  
                  }  
          }' | awk '{$1=$1}{ print }' | sed 's/\%//' | sed 's/ /\, /g' > ${TEMPFILE1}
          
cat ${TEMPFILE1} | while read LINE
do
    echo "${THIS_SERVER}, ${LINE}, ${DF_DATE}">> ${EXTERNAL_DIR}/am_os_space_load.dbf
done

sqlplus -s ${CONNECT}\@${ORACLE_SID} <<- SQL100 > ${TEMPFILE2}
        SET PAGES 0
        SET FEEDBACK OFF
        SET TAB OFF
	SELECT 'Mountpoint ' || mountpoint || ' is ' || pctused || '% full' 
        FROM  AM_OS_SPACE_LOAD 
        WHERE pctused > 20
	ORDER BY pctused DESC;
	exit;
SQL100

if [[ -f ${TEMPFILE2} ]]
then
    cat ${TEMPFILE2}
fi

exit 0

