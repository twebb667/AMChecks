#!/bin/ksh
##################################################################################
# Name             : os_space_check.ksh
# Author           : Tony Webb
# Created          : 12 January 2016
# Type             : Korn shell script
# Version          : 010
# Parameters       : 
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  environment problems
#                    54  Missing files
# Notes            
# ~~~~~~
# Run this on every server where you want to report OS space usage.
# For this to work, add a daily cron to run this and also ensure that the external
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
#    DF_DOW          VARCHAR2(10 CHAR),
#    DF_TIMESTAMP    VARCHAR2(30 CHAR)
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
# This will need an oracle directory with full access to 'amu'. The actual 
# directory for this will be ~oracle/amchecks/extenal_tables
#
# In addition: create 2 directories: ~/home/amchecks/external_data
#                                    /tmp/amchecks
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 12/01/16 | T. Webb    | Original
##################################################################################

#AMCHECK Directories
typeset EXTERNAL_DIR=~oracle/amchecks/external_tables
typeset TEMP_DIR=/tmp/amchecks

typeset CRON_MODE='Y'
typeset DATAFILE
typeset DF_TIMESTAMP=`date +"%a %d %b %Y %H:%M:%S"`
typeset DF_DOW=`date +%A`
typeset -i NEW_PCT=0
typeset NEW_LINE
typeset -i OLD_PCT=0
typeset THIS_SERVER=`uname -a | cut -d' ' -f2 | cut -d'.' -f1`
typeset TEMPFILE1="${TEMP_DIR}/temp_am_os_space_load"
typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -c (running from cron)" 

#######
# Main
#######

if [[ $# -ne 0 ]]
then
   print "Error please do not specify any positional parameters"
   exit 50
fi
#echo "debug 1: DF_TIMESTAMP is ${DF_TIMESTAMP}"
DF_TIMESTAMP=`echo ${DF_TIMESTAMP} | sed 's/ /\-/g' | sed 's/GMT//g' | sed 's/AM//g' || sed 's/PM//g'`
#echo "debug 2: DF_TIMESTAMP is ${DF_TIMESTAMP}"

if [[ ! -d ${EXTERNAL_DIR} ]]
then
    mkdir -p ${EXTERNAL_DIR} 
fi

if [[ ! -d ${TEMP_DIR} ]]
then
    mkdir -p ${TEMP_DIR} 
fi

DATAFILE="${EXTERNAL_DIR}/am_os_space_load.dbf"
NEW_DATAFILE="${EXTERNAL_DIR}/am_os_space_load_new.dbf"

if [[ ! -f ${DATAFILE} ]] 
then
    touch ${DATAFILE}
fi

if [[ -f ${NEW_DATAFILE} ]]
then
   rm -f ${NEW_DATAFILE}
fi

if [[ `grep -wc ${DF_DOW} ${DATAFILE}` -eq 0 ]]
then
    rm -f ${DATAFILE}
    touch ${DATAFILE}
fi

#echo "debug 1: DOW is ${DF_DOW}"

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
         
if [[ `cat ${DATAFILE} | wc -l` -eq 0 ]] || [[ `cat ${DATAFILE} | wc -l` -lt `cat ${TEMPFILE1} | wc -l ` ]]
then
    cat ${TEMPFILE1} | while read LINE
    do
        echo "${THIS_SERVER}, ${LINE}, ${DF_DOW}, ${DF_TIMESTAMP}">> ${NEW_DATAFILE}
    done
    mv ${NEW_DATAFILE} ${DATAFILE}
else
    IFS=', '
    cat ${DATAFILE} | sed 's/  \+/ /g' | while read LINE
    do
        OLD_PCT=`echo ${LINE} | cut -d' ' -f6`
        MOUNTPOINT=`echo ${LINE} | cut -d' ' -f7`
        NEW_LINE=`grep -w ${MOUNTPOINT}$ ${TEMPFILE1}`
        ##NEW_LINE=`grep -w ${MOUNTPOINT} ${TEMPFILE1}`
        NEW_PCT=`echo ${NEW_LINE} | cut -d' ' -f5`
        if [[ ${NEW_PCT} -gt ${OLD_PCT} ]]
        then
            echo "${THIS_SERVER}, ${NEW_LINE}, ${DF_DOW}, ${DF_TIMESTAMP}">> ${NEW_DATAFILE}
        else
            echo ${LINE} | sed 's/ /\, /g' >> ${NEW_DATAFILE}
        fi
    done
    mv ${NEW_DATAFILE} ${DATAFILE}
fi

exit 0

