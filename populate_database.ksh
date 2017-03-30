#!/bin/ksh
##################################################################################
# Name             : populate_database.ksh
# Author           : Tony Webb
# Created          : 14 August 2014
# Type             : Korn shell script
# Version          : 020
# Parameters       : 
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  Environment problems
#                    54  Missing files
#
# Notes            : Note that the sidskip file to be used is the amchecks one
#                    not the is_oracle_ok one.
#
#                    This script won't like any constraints being in place to 
#                    the am_server table...
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 14/08/14 | T. Webb    | Original
# 020     | 18/08/14 | T. Webb    | Sidskip processing added
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
typeset SCRIPT="${TEMP_DIR}/populate_database.sql"
typeset -u SID
typeset SIDSKIPFILE="${TEMP_DIR}/amchecks_sidskipfile"
typeset TEMPFILE1="${TEMP_DIR}/populate_database.lst"
typeset TEMPFILE2="${TEMP_DIR}/populate_database_sortedsids"
typeset TEMPFILE3="${TEMP_DIR}/populate_database_sortedskipsids"
typeset TEMPFILE4="${TEMP_DIR}/populate_database_sidlist"
typeset THIS_SERVER=`hostname -s`
typeset TNSNAMES
typeset TNS_ADMIN=${TEMP_DIR}

# TNSPING location Can only be set once we know ORACLE_HOME..
typeset TNSPING=${ORACLE_HOME}/bin/tnsping

if [[ -f ${SCRIPT} ]]
then
    rm -f ${SCRIPT}
fi

touch ${SCRIPT}
touch ${AMCHECK_DIR}/amchecks_sidskipfile
cp ${AMCHECK_DIR}/amchecks_sidskipfile ${SIDSKIPFILE}
cp ${AMCHECK_DIR}/tnsnames.ora ${TEMP_DIR}/.

echo "Please note that this script is horribly inefficient and will take an age to run."
echo "Hopefully you won't need to run it too often!"

grep -v -e '^#' ${TEMP_DIR}/tnsnames.ora  | grep -i '^[a-zA-Z]' | cut -d '=' -f1  | sort -u > ${TEMPFILE2}
cat ${SIDSKIPFILE}  | sort -u > ${TEMPFILE3}
join -v 1 ${TEMPFILE2} ${TEMPFILE3} > ${TEMPFILE4}
cat ${TEMPFILE4} | while read SID
do
  echo ${SID}
  HOST=`${TNSPING} ${SID} | tr "[:lower:]" "[:upper:]" | sed '/SID/s//SERVICE_NAME/' | perl -ne '$h_sid="$1" if /\(HOST\s=\s([^)]+)\).+\(SERVICE_NAME\s=\s([^)]+)/;print "$h_sid\n" if /\((\d+)\s*MSEC\)/;'`
    if [[ -z ${HOST} ]]
    then
        print "/* Host ${HOST} not found for ${SID} (tnsping failed). */" | tee -a  ${SCRIPT}
    else
#        print "${HOST} ${SID}"
 
        echo "MERGE INTO amo.am_database a
USING
    (SELECT '${SID}'  AS database_name,
            '${HOST}' AS server
     FROM    dual) b
ON (a.database_name = b.database_name)
WHEN MATCHED THEN
     UPDATE SET a.server   = b.server,
                a.disabled = 'N'
WHEN NOT MATCHED THEN
     INSERT (a.database_name, a.server, a.disabled)
     VALUES (b.database_name, b.server, 'N');

" >> ${SCRIPT}
    fi
done

###################################################                
# Now take care of the entries in the sidskip file
# N.B. We may not know the host details as a ping
# may fail, so no new entries are added to the
# database from the sidskip file.
###################################################                
cat ${TEMPFILE3} | while read SID
do
   echo "MERGE INTO amo.am_database a
USING
    (SELECT '${SID}'  AS database_name,
            '${HOST}' AS server
     FROM    dual) b
ON (a.database_name = b.database_name)
WHEN MATCHED THEN
     UPDATE SET a.server   = b.server,
                a.disabled = 'Y'
WHEN NOT MATCHED THEN
     INSERT (a.database_name, a.server, a.disabled)
     VALUES (b.database_name, b.server, 'Y');

" >> ${SCRIPT}
done
echo "running script: ${SCRIPT}"

sqlplus -s -L ${CONNECT}\@${ORACLE_SID} <<- SQL10 >${TEMPFILE1} 2>&1
set pages 0
start ${SCRIPT}
exit;
SQL10

exit 0

