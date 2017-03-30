#!/bin/ksh
##################################################################################
# Name             : is_progress_ok
# Author           : Tony Webb
# Created          : 27 Jan 2017
# Type             : Korn shell script
# Version          : 030
# Parameters       : v (verbose)
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 27/01/17 | T. Webb    | Original
# 020     | 01/02/17 | T. Webb    | Added verbose flag (positional)
# 030     | 03/02/17 | T. Webb    | Replaced broker check with less version 
#         |          |            | specific check on any 'biw' process
#################################################################################

if [[ -f ${HOME}/.amchecks ]]
then
    . ${HOME}/.amchecks
elif [[ -f ${HOME}/.profile ]]
then
    . ${HOME}/.profile
fi

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR="/tmp/amchecks"

# Read environments for the morning checks
# this won't work on some remote servers so repeat code here instead :-( . ${AMCHECK_DIR}/.amcheck
export AMCHECK_TNS="amu/gl1tterbug@(DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = UATERM2DB01.grpdom.vwuk.corp)(PORT = 1522)) (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = DOUDBAM1)))"

typeset DBPATHLIST=${TEMP_DIR}/progdbcheck
typeset -u ERROR_IND='N'
typeset -l OWNER
typeset -l SERVER_ABBREV=`hostname | cut -d'.' -f1`
typeset TEMPFILE1="${TEMP_DIR}/os_prog_chk1.lst"
typeset TEMPFILE2="${TEMP_DIR}/os_prog_chk2.lst"
typeset TEMPFILE3="${TEMP_DIR}/os_prog_chk3.lst"
typeset TEMPFILE4="${TEMP_DIR}/os_prog_chk4.lst"
typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -v (verbose mode)"
typeset -u VERBOSE_IND='N'

#######
# Main
#######

#################################################################################################
# Get parameters. Note that optional (-x) parameters do not work with how this script is called.
##################################################################################################
if [[ $# -gt 0 ]] &&  [[ $1 = "v" ]]
then
    VERBOSE_IND='Y'
fi

if [[ ! -d ${TEMP_DIR} ]]
then
    mkdir -p ${TEMP_DIR}
fi

sqlplus -s "${AMCHECK_TNS}" <<- SQL100 > ${TEMPFILE1}
	set pages 0
	set feedback off
	SELECT instance_name FROM amo.am_prog_instance WHERE server = '${SERVER_ABBREV}' ORDER BY 1;`
	exit;
SQL100

#echo "Temp file is ${TEMPFILE1}"
cat ${TEMPFILE1} | sed '/^$/d' | while read INSTANCE
do
#    INST_COUNT=`ps -elf | grep _probrkr | grep -v grep | grep -wc ${INSTANCE}`
    INST_COUNT=`ps -fu ${INSTANCE} | grep _mprshut | grep -v grep | grep -wc biw`
    if [[ ${INST_COUNT} -lt 1 ]]
    then
        echo "ERROR - Instance ${INSTANCE} is not running!"
        ERROR_IND='Y'
    else
	########################################
	# Check all databases for this instance
	########################################
        # We need to do more than just check processes now. Need to run a progress utility
	DIRNAME=`cat /etc/passwd | grep ^${INSTANCE} | cut -d':' -f6`
	if [[ ! -x ${DIRNAME}/bin/Affinity_Vars ]]
	then
	    echo "Error - expected file ${DIRNAME}/bin/Affinity_Vars not found or not executable "
            ERROR_IND='Y'
        else
	    cd ${DIRNAME}/bin
            . ./Affinity_Vars
	    ####################################################
	    # Now get a list of all databases for this instance
	    ####################################################
		sqlplus -s "${AMCHECK_TNS}" <<- SQL200 > ${TEMPFILE2}
		set pages 0
		set feedback off
		SELECT 'proutil ${DIRNAME}' || '/Database/' || parent_name || '/' || db_name || '.db -C holder'
		FROM amo.am_prog_database
		WHERE server = '${SERVER_ABBREV}'
		AND instance_name = '${INSTANCE}'
		AND disabled <> 'Y'
		ORDER BY 1;`
		exit;
SQL200
#	cat ${TEMPFILE2}
	    chmod 700 ${TEMPFILE2}
	    . ${TEMPFILE2} > ${TEMPFILE3}
	    if [[ `grep -c "errno" ${TEMPFILE3}` -gt 0 ]]
	    then
	        echo "  ${INSTANCE} on ${SERVER_ABBREV} - NOT OK!!"
	        grep "errno" ${TEMPFILE3} 
            else
	        echo "  ${INSTANCE} on ${SERVER_ABBREV} - OK"
                if [[ ${VERBOSE_IND} = "Y" ]]
                then
	            cat ${TEMPFILE3} 
                fi
            fi 
        fi 
    fi
done

if [[ ${ERROR_IND} = "Y" ]]
then
    exit 1
fi

