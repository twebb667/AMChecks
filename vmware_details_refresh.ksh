#!/bin/ksh
##################################################################################
# Name             : vmware_details_refresh.ksh
# Author           : Tony Webb
# Created          : 05 January 2017
# Type             : Korn shell script
# Version          : 010
# Parameters       : -a alternative e-mail address
#                    -m (mail)
#                    -s (smart mail - only e-mail on error)
# Returns          : 0   Success
#                    50  Wrong parameters
# Notes            
# ~~~~~~
#
# Thuis script won't work as it is on your site but could probably be made to work with 
# corrections in path and changes due to file structure so I'm leaving it anyhow.
#
# Run this using a frequency that matches ypur externally produced vmware information dump
# (probably made available to you by whoever looks after vmware where you work).
#
# Two external tables are used - one for the latest info and one for the previous one
# (am_vmware_server and am_vmware_server_prev).
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 05/01/17 | T. Webb    | Original
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environments for the morning checks
. ${AMCHECK_DIR}/.amcheck

typeset EXTERNAL_DIR=~oracle/amchecks/external_tables
typeset MAIL_BUFFER="${TEMP_DIR}/vmware_mail_info"
typeset MAIL_TITLE='VMWare Details'
typeset NEW_TIMESTAMP
typeset PREV_TIMESTAMP
typeset -i RET=0
typeset SEND_MAIL='N'
typeset TEMP_DIR=/tmp/amchecks
typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -a alternative e-mail address -m (mail) -s (smart mail)" 

#######
# Main
#######

# Read standard amchecks functions
. ${AMCHECK_DIR}/functions.ksh

rm -f ${MAIL_BUFFER}

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!

while getopts a:ms o
do      case "$o" in
        a)      MAIL_RECIPIENT="${OPTARG}"
                SEND_MAIL="Y";;
        m)      SEND_MAIL="Y";;
        s)      SEND_MAIL="M";;
        [?])    print -- "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}" 
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 0 ]]
then
   print "Error please do not specify any positional parameters" 
   exit 50
fi

if [[ ! -d ${EXTERNAL_DIR} ]]
then
    mkdir -p ${EXTERNAL_DIR} 
fi

if [[ ! -d ${TEMP_DIR} ]]
then
    mkdir -p ${TEMP_DIR} 
fi

DATAFILE="${EXTERNAL_DIR}/am_vmware_server.dbf"
PREV_DATAFILE="${EXTERNAL_DIR}/am_vmware_server_prev.dbf"
NEW_DATAFILE="${TEMP_DIR}/am_vmware_server.dbf"

if [[ -f ${DATAFILE} ]] 
then
    PREV_TIMESTAMP=`ls -l ${DATAFILE} | sed 's/  / /' | cut -d' ' -f6-8`
else
    PREV_TIMESTAMP='New'
fi

if [[ -f ${NEW_DATAFILE} ]] 
then
    NEW_TIMESTAMP=`ls -l ${NEW_DATAFILE} | sed 's/  / /' | cut -d' ' -f6-8`
else
    NEW_TIMESTAMP='Missing'
fi

if [[ ${NEW_TIMESTAMP} == "Missing" ]]
then
    echo "No new VMWARE file found. Expecting to find ${NEW_DATAFILE}. Current file has a timestamp of ${PREV_TIMESTAMP}" >> ${MAIL_BUFFER}
    RET=1
else
    if [[ -f ${DATAFILE} ]]
    then
        mv -f ${DATAFILE} ${PREV_DATAFILE}
        RET=$?
        if [[ ${RET} != 0 ]]
        then
            echo "Error moving existing VMWARE file ${DATAFILE} to ${PREV_DATAFILE}" >> ${MAIL_BUFFER}
            RET=1
        fi
    fi

#    cp --preserve=timestamps -f ${NEW_DATAFILE} ${DATAFILE}
#    Changed to remove double-quotes in generated file from vmware. Not a biggie.

    tr -d '\015' < ${NEW_DATAFILE} | sed 's/\"//g'  | sed 's/$/\,/g' > ${DATAFILE}
    RET=$?
    if [[ ${RET} == 0 ]]
    then
        echo "VMWARE details updated. Info is current as of ${NEW_TIMESTAMP} (was ${PREV_TIMESTAMP})" >> ${MAIL_BUFFER}
        mv -f ${NEW_DATAFILE} ${NEW_DATAFILE}.moved
    else
        echo "Error copying new VMWARE file ${NEW_DATAFILE} to ${DATAFILE}" >> ${MAIL_BUFFER}
        RET=1
    fi
fi

if [[ ${SEND_MAIL} == "Y" ]] 
then
   f_mail Vmware_details blue "${MAIL_RECIPIENT}" "${MAIL_BUFFER}" ${MAIL_TITLE}
elif [[ ${SEND_MAIL} == "M" ]] && [[ ${RET} != 0 ]]
then
   MAIL_TITLE="WARNING - ${MAIL_TITLE}"
   f_mail Vmware_details red "${MAIL_RECIPIENT}" "${MAIL_BUFFER}" ${MAIL_TITLE}
fi

exit 0

