#!/bin/ksh
##################################################################################
# Name             : space_check.ksh
# Author           : Tony Webb
# Created          : 12 June 2014
# Type             : Korn shell script
# Version          : 040
# Parameters       : -r  (refresh only)
#                    -m  (report in meg, not gig)
#                    -c  (cron mode)
#                    -l  (log space to the amchecks database)
#                    database 
# Returns          : 0   Success
#                    50  Wrong parameters
#                    52  Storing reports at the megabyte level is disabled
#                    51  environment problems
#                    54  Missing files
#
# Notes            : to only be run on a local database
#
#                    Run the following (or use an equivalent analytic function) 
#                    to see the latest space results:
#
#                    SELECT a.database_name, 
#                           a.tablespace_name, 
#                           a.max_space, 
#                           a.actual_space, 
#                           a.used_space, 
#                           a.free_space, 
#                           a.space_time
#                    FROM   am_database_space a,
#                           (SELECT  MAX(space_time) AS latest, 
#                                    tablespace_name, 
#                                    database_name 
#                            FROM    am_database_space 
#                            GROUP BY database_name, 
#                                     tablespace_name) b
#                    WHERE  a.database_name   = b.database_name
#                    AND    a.tablespace_name = b.tablespace_name
#                    AND    a.space_time      = b.latest;
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 12/06/14 | T. Webb    | Original
# 020     | 17/06/14 | T. Webb    | Functions moved to separate file
# 030     | 20/06/14 | T. Webb    | Added inserts into db
# 040     | 14/10/14 | T. Webb    | Added cron mode
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environments for the morning checks
source ${AMCHECK_DIR}/.amcheck

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -r (refresh only) -m (report in meg not gig) database"

typeset ACTUAL_SPACE
typeset CRON_MODE='N'
typeset DFSPACETIME
typeset EXTERNAL_DIR="${AMCHECK_DIR}/external_tables"
typeset -i ERRORCOUNT
typeset FREE_SPACE
typeset INSERT_TIME=`date +'%d/%m/%y-%k:%M:%S'` # avoid whitespace
typeset LANG=en_GB
typeset LINE
typeset LOG_TO_DB='N'
typeset MAX_SPACE
typeset MEG='N'
typeset ORACLE_SID
typeset REFRESH='N'
typeset SQL_FILE="${AMCHECK_DIR}/true_space_gig.sql"
typeset TABLESPACE_NAME
typeset TEMPFILE1="${TEMP_DIR}/space_check1.lst"
typeset TEMPFILE2="${TEMP_DIR}/space_check2.lst"
typeset TEMPFILE3="${TEMP_DIR}/space_check3.sql"
typeset TEMPFILE4="${TEMP_DIR}/space_check4.lst"
typeset TEMPFILE5="${TEMP_DIR}/space_check5.lst"
typeset TEMPFILE6="${TEMP_DIR}/space_check6.lst"
typeset TEMPFILE7="${TEMP_DIR}/space_check7.sql"
typeset -u UC_SID
typeset USED_SPACE

#############
# Functions
#############

# Read standard amchecks functions
#source ~oracle/amchecks/functions.ksh
. ${AMCHECK_DIR}/functions.ksh

##############
# Run scripts 
##############

function f_run    
{                  
    typeset DIR_NAME=$1
    typeset FILE_NAME=$2
    print Directory name is ${DIR_NAME}
    print File name is ${FILE_NAME}

    RET=$?
    if [[ ${RET} -ne 0 ]]
    then
        if [[ ${CRON_MODE} = 'Y' ]]
        then 
            print Error ${RET} running f_run on ${FILE_NAME}
        else
            f_redprint Error ${RET} running f_run on ${FILE_NAME}
        fi
    fi
}

#######
# Main
#######

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!
# Note that 'g' will be permitted (assume caller wants a report in gig and was unfamiliar with parameters)

while getopts cglmr o
do      case "$o" in
        c)      CRON_MODE="Y";;
        g)      MEG='N';;
        l)      LOG_TO_DB='Y';;
        m)      MEG='Y';;
        r)      REFRESH='Y';;
        [?])    print "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 1 ]]
then
   if [[ ${CRON_MODE} = 'Y' ]]
   then 
        print "Error please specify one parameter - database name of a local database"
   else
        f_redprint "Error please specify one parameter - database name of a local database"
   fi
   exit 54
else
    export ORACLE_SID=$1
fi

if [[ ${MEG} = 'Y' ]]
then
    SQL_FILE="${AMCHECK_DIR}/true_space_meg.sql"
fi

EXTERNAL_DIR=~oracle/amchecks/external_tables/${ORACLE_SID}
if [[ `ps aux | grep -icw ora_smon_${ORACLE_SID}` -lt 1 ]]
then
    if [[ ${CRON_MODE} = 'Y' ]]
    then 
        print Database ${ORACLE_SID} is not located on this server. 'df space' may be stale and age will NOT be shown.
    else
        f_greenprint Database ${ORACLE_SID} is not located on this server. 'df space' may be stale and age will NOT be shown.
    fi
    DFSPACETIME="?"
else
    if [[ ! -d ${EXTERNAL_DIR} ]]
    then
        mkdir ${EXTERNAL_DIR}
    fi
    #########################################################
    # Populate the flatfile/datafile for the external tables
    #########################################################

    sqlplus -s ${CONNECT}\@${ORACLE_SID} <<- SQL100 > ${TEMPFILE1}
    set pages 0
    set feedback off
    set lines 200
    SELECT SUBSTR(file_name, 1, INSTR(file_name, '/', -1, 1)-1) || ' ' || file_name FROM dba_data_files 
    union all
    SELECT SUBSTR(file_name, 1, INSTR(file_name, '/', -1, 1)-1) || ' ' || file_name FROM dba_temp_files order by 1;
    exit;
SQL100
    rm -f ${EXTERNAL_DIR}/dfspace.dbf
    touch ${EXTERNAL_DIR}/dfspace.dbf
    cat ${TEMPFILE1} | sed '/^$/d' | while read LINE
    do
        set ${LINE}
        DIR_NAME=${1}
        FULL_FILE_NAME=${2}
        FILE_NAME=`basename ${2}`
        MOUNT=`/bin/df ${1} -PmB1 | sed '/[  ][  ]*/s// /g ' | grep -v Filesystem | cut -d' ' -f1,4,6 `
        print ${FULL_FILE_NAME} ${FILE_NAME} ${DIR_NAME} ${MOUNT} ${INSERT_TIME} >> ${EXTERNAL_DIR}/dfspace.dbf
    done
    DFSPACETIME=`stat --format=%y ${EXTERNAL_DIR}/dfspace.dbf | cut -d'.' -f1`
fi

rm -f ${TEMPFILE2}
if [[ ${REFRESH} = 'N' ]]
then
    echo "debug 1"
    sqlplus -s ${CONNECT}\@${ORACLE_SID} <<- SQL200 > ${TEMPFILE2}
    @${SQL_FILE}
    exit;
SQL200
cat ${TEMPFILE2}
fi

if [[ ${CRON_MODE} = 'Y' ]]
then 
    print " ** DF space valid as of: ${DFSPACETIME} **"
else
    f_greenprint " ** DF space valid as of: ${DFSPACETIME} **"
fi

if [[ ${LOG_TO_DB} = 'Y' ]] 
then
    ##################################################################################################
    # The next bit of code is a bit complex but it has been written to hopefully minimise the number
    # of times sqlplus is called and also the number of selects. Sorry it's not very elegant!
    ##################################################################################################

    if [[ ${MEG_IND} = 'Y' ]]
    then
        if [[ ${CRON_MODE} = 'Y' ]]
        then 
            print Logging to the morning check database is disabled for reports at the megabyte level
        else
            f_yellowprint Logging to the morning check database is disabled for reports at the megabyte level
        exit 52 
        fi
    fi

    rm -f ${TEMPFILE3}
    touch ${TEMPFILE3}
    rm -f ${TEMPFILE4}
    touch ${TEMPFILE4}
    rm -f ${TEMPFILE5}
    touch ${TEMPFILE5}
    rm -f ${TEMPFILE6}
    touch ${TEMPFILE6}
    rm -f ${TEMPFILE7}
    echo "set termout off" >  ${TEMPFILE7}

    UC_SID=${ORACLE_SID}
    cat ${TEMPFILE2} | grep '\[' | while read LINE
    do
        set ${LINE}
        TABLESPACE_NAME=${1}
        MAX_SPACE=${2}
        ACTUAL_SPACE=${3}
        USED_SPACE=${4}
        FREE_SPACE=${5}
    
        print ${UC_SID} ${TABLESPACE_NAME} ${MAX_SPACE} ${ACTUAL_SPACE} ${USED_SPACE} ${FREE_SPACE} >> ${TEMPFILE3}
    done

    ###########################################################################################
    # Need to get current stored details to decide if we need to update the stored information
    ###########################################################################################
    sqlplus -s ${CONNECT}\@${ORACLE_SID} <<- SQL300 > ${TEMPFILE4}
    set lines 200
    ALTER SESSION SET NLS_DATE_FORMAT='dd-mm-yy hh24:mi:ss';
    SELECT RPAD(tablespace_name,30),
           TO_CHAR(max_space,'999,990.99'),
           TO_CHAR(actual_space, '999,990.99'),
           TO_CHAR(used_space, '9,990.99'),
           TO_CHAR(free_space, '9,990.99')
    FROM   (SELECT tablespace_name, max_space, actual_space, used_space, free_space, space_time, last_value(space_time) 
            OVER (PARTITION BY tablespace_name ORDER BY space_time) AS latest 
            FROM amo.am_database_space 
              WHERE database_name = '${UC_SID}'
            ORDER BY tablespace_name)
    WHERE space_time = latest;
    exit;
SQL300
    cat ${TEMPFILE4} | grep '\.' | while read LINE
    do
        set ${LINE} 
        print ${UC_SID} ${1} ${2} ${3} ${4} ${5} >> ${TEMPFILE5}
    done
    diff ${TEMPFILE3} ${TEMPFILE5} | grep '<' | sed 's/< //g' > ${TEMPFILE6}

    cat ${TEMPFILE6} | while read LINE
    do
        set $LINE
        print "INSERT INTO amo.am_database_space (database_name, tablespace_name, max_space, actual_space, used_space,free_space) VALUES" >> ${TEMPFILE7}
        print '('\'${1}\', \'${2}\', ${3}, ${4}, ${5}, ${6} ');' '\n' >> ${TEMPFILE7}
    done

    #####################
    # Insert new values 
    #####################
    sqlplus -s ${AMCHECK_TNS} <<- SQL400 
	@${TEMPFILE7}
	exit;
SQL400
fi

exit 0

