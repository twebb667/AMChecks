#!/bin/ksh
##################################################################################
# Name             : reset_password.ksh
# Author           : Tony Webb
# Created          : 05 October 2015
# Type             : Korn shell script
# Version          : 010
# Parameters       : username password
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  Environment problems
#
# Usage            : (Re)sets one of the amchecks user passwords
#
# Notes            : This will set the passwords to be the same everywhere;
#                    The list of SIDS will be taken from the database (no '-t')
#                    The password on the control database must not be about to change
#                    so if you are getting a warning, fix that first before
#                    running this script.
#
#                    Remember to keep ~/.amchecks secure if you need to edit it
#                    for new passwords once you are done here.
#                    
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 05/10/15 | T. Webb    | Original
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environment variables for the morning checks
source ${AMCHECK_DIR}/.amcheck

# Read standard amchecks functions
source ${AMCHECK_DIR}/functions.ksh

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -d database username password"
typeset -l HOST
typeset LANG=en_GB
typeset -l SID
typeset OLD_PASWD
typeset ONE_DB
typeset PASWD
typeset SIDSKIPFILE="${TEMP_DIR}/amchecks_sidskipfile"
typeset TEMPFILE1="${TEMP_DIR}/reset_password_sids.lst"
typeset TEMPFILE2="${TEMP_DIR}/reset_password.lst"
typeset THIS_SERVER=`hostname -s`
typeset TNSNAMES
typeset TNS_ADMIN=${TEMP_DIR}
typeset -l USERNAME

# TNSPING location Can only be set once we know ORACLE_HOME..
typeset TNSPING=${ORACLE_HOME}/bin/tnsping

##################
# Local Functions
##################

function f_run
{
    typeset CONNECT_STRING
    typeset SID=$1
    typeset -u UPPER_SID=${SID}
    typeset -L40 PRINT_SID="Changing password for user ${USERNAME} on ${UPPER_SID} "
       
#    case "${USERNAME}" in
#    "amo") CONNECT_STRING=${OWNER_CONNECT}
#         ;;
#    "amu") CONNECT_STRING=${CONNECT}
#         ;;
#    "amr") CONNECT_STRING=${READER_CONNECT}
#         ;;
#    esac 

    CONNECT_STRING=${USERNAME}/${OLD_PASWD}
    if [[ ! -z ${CONNECT_STRING} ]]
    then
        print "Resetting password for user ${USERNAME} on ${SID}"
        echo "connecting using ${CONNECT_STRING}@${SID} and running ALTER USER ${USERNAME} identified by ${PASWD} REPLACE ${OLD_PASWD}"
	sqlplus -s -L ${CONNECT_STRING}@${SID} <<- SQL200 > ${TEMPFILE2}
		set pages 0
		SET FEEDBACK OFF
		ALTER USER ${USERNAME} identified by ${PASWD} REPLACE ${OLD_PASWD} ;
		exit;
	SQL200
	cat ${TEMPFILE2}

        RET=$?
        if [[ ${RET} -ne 0 ]]
        then
            print "Error. See below. Aborting"
            cat ${TEMPFILE2}
            exit 50
        fi
    else
        print "Problem identifying connect parameters. Exiting."
        exit 51
    fi

    # Need to remove logfile for security reasons
    rm -f ${TEMPFILE2}
}

#######
# Main
#######

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!
while getopts d: o
do      case "$o" in
        d)      ONE_DB=${OPTARG};;
        [?])    print "${THISSCRIPTNAME}: invalid parameters supplied \n${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 3 ]]
then
   print "Please specify username, password and old_password as positional parameters. ${USAGE}"
   exit 50
fi

USERNAME=${1}
PASWD=${2}
OLD_PASWD=${3}

if [[ ${USERNAME} != 'amo' ]] && [[ ${USERNAME} != 'amu' ]] && [[ ${USERNAME} != 'amr' ]] 
then
   print "Please specify a valid AMChecks username. ${USAGE}"
   exit 50
fi

touch ${AMCHECK_DIR}/amchecks_sidskipfile
cp ${AMCHECK_DIR}/amchecks_sidskipfile ${SIDSKIPFILE}
cp ${AMCHECK_DIR}/tnsnames.ora ${TEMP_DIR}/.

if [[ ! -z ${ONE_DB} ]]
then
   f_run ${ONE_DB}
else
    sqlplus -s ${AMCHECK_TNS} <<- SQL100 > ${TEMPFILE1}
	set pages 0
	SET FEEDBACK OFF
	SELECT database_name FROM amo.am_database WHERE disabled <> 'Y' ORDER BY 1;
	exit;
	SQL100

    RET=$?
    if [[ ${RET} -ne 0 ]]
    then
        print "Error. See below. Aborting"
        cat ${TEMPFILE1}
        exit 50
    fi

    cat ${TEMPFILE1} | sed '/^$/d' | while read SID
    do
        f_run ${SID}
    done
fi

exit 0

