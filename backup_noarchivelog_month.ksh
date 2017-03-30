#!/bin/ksh
##################################################################################
# Name             : backup_noarchivelog_month.ksh
# Author           : Tony Webb
# Created          : 05 September 2016
# Type             : Korn shell script
# Version          : 010
# Returns          : 0  - Success
#                    50 - Invalid number/type of parameters
#                    51 - SID not supplied
#                    52 - DEST not correct
#                    53 - LOGDEST not correct
#                    54 - Invalid SID
#
# Parameters       : -d days (retention period in days)
#                    Database name (mandatory)
# Notes            : This script is not really all that portable
#                    but it might be useful to refer to in writing
#                    your own scripts.
#
#---------+----------+------------+-----------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+-----------------------------------------------
# 010     | 05/09/16 | T. Webb    | Original
##################################################################################

typeset -i PCTUSED
typeset -i RETENTION_DAYS=40
typeset THISSCRIPTNAME=`basename $0`
typeset -i THRESHOLD=80
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -d days (disk retention days/purge days) database"

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!

while getopts d: o
do      case "$o" in
        d)      RETENTION_DAYS="${OPTARG}"
                PURGE_IND="Y";;
        [?])    print -- "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 1 ]]
then
    echo "Please specfy your ORACLE_SID"
    exit 51
fi

export ORACLE_SID=$1

# Establish oratab depending on O/S
if [[ "`uname -a | cut -c1-3`" == "Sun" ]]
then
    ORATAB=/var/opt/oracle/oratab
else
    ORATAB=/etc/oratab
fi

export ORATAB

# Define ORACLE_HOME
if grep "^${ORACLE_SID}:" ${ORATAB} >/dev/null
then
    export ORACLE_HOME=`grep "^${ORACLE_SID}" ${ORATAB} | awk -F: '{print $2}'`
    export LD_LIBRARY_PATH=${ORACLE_HOME}/lib;
    export PATH=${PATH}:${ORACLE_HOME}/bin
else
    echo "Invalid SID"
    exit 54
fi

# Environmental variables defined based on SID
typeset DEST=/u01/app/oracle/backup/rman/${ORACLE_SID}
typeset LOGDEST=/u01/app/oracle/backup/rman/${ORACLE_SID}/LOG

if [[ ! -d ${DEST} ]]
then
    echo "Please create directory ${DEST} and make sure it has sufficient space for a backup"
    exit 52
elif [[ ! -d ${LOGDEST} ]]
then
    echo "Please create directory ${LOGDEST} for logging the output of your backups"
    exit 53
fi

DATESTAMP=`date '+%y%m%d%H%M'`
export NLS_DATE_FORMAT='Mon DD YYYY HH24:MI:SS'

# Define RMAN catalog connection string
export RMAN_CONN='rman/change_this@RMAN_TNS_ALIAS'

#################################
# Right, onto the useful bit...
#################################

rman target / catalog ${RMAN_CONN} <<-RMAN1 >${LOGDEST}/${ORACLE_SID}_RMAN_COLDBACKUP_MONTH_${DATESTAMP}.log
RESYNC CATALOG;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
run {
sql "create pfile=''${DEST}/${ORACLE_SID}_PFILE_`date +%d%m%Y`_MONTH.ora'' from spfile";
sql "alter database backup controlfile to trace as ''${DEST}/${ORACLE_SID}_TRC_`date +%d%m%Y_%H%m%S`_MONTH.trc''";
ALLOCATE CHANNEL CH01 TYPE DISK MAXPIECESIZE 5G;
BACKUP AS COMPRESSED BACKUPSET DATABASE FORMAT '${DEST}/%d_%U_%T_RMAN_MONTH.bkp' KEEP UNTIL TIME 'SYSDATE+40' NOLOGS;
BACKUP CURRENT CONTROLFILE FORMAT '${DEST}/${ORACLE_SID}_controlfile_%s_%p_%t.ctl';
RELEASE CHANNEL CH01;
}
ALTER DATABASE OPEN;
exit

RMAN1

find ${DEST} -maxdepth 1 -name '${ORACLE_SID}*MONTH.ora' -mtime +${RETENTION_DAYS} -exec ls -l {} \;
find ${DEST} -maxdepth 1 -name '${ORACLE_SID}_TRC_*MONTH.trc' -mtime +${RETENTION_DAYS} -exec ls -l {} \;
find ${DEST} -maxdepth 1 -name '${ORACLE_SID}*MONTH.bkp' -mtime +${RETENTION_DAYS} -exec ls -l {} \;
find ${LOG_DEST} -maxdepth 1 -name '${ORACLE_SID}_RMAN_COLDBACKUP_MONTH*.log' -mtime +${RETENTION_DAYS} -exec ls -l {} \;

echo "Purging old files - Files older than ${RETENTION_DAYS} days"

find ${DEST} -maxdepth 1 -name '${ORACLE_SID}*MONTH.ora' -mtime +${RETENTION_DAYS} -exec rm -v -f {} \;
find ${DEST} -maxdepth 1 -name '${ORACLE_SID}_TRC_*MONTH.trc' -mtime +${RETENTION_DAYS} -exec rm -v -f {} \;
find ${DEST} -maxdepth 1 -name '${ORACLE_SID}*MONTH.bkp' -mtime +${RETENTION_DAYS} -exec rm -v -f {} \;
find ${LOG_DEST} -maxdepth 1 -name '${ORACLE_SID}_RMAN_COLDBACKUP_MONTH*.log' -mtime +${RETENTION_DAYS} -exec rm -v -f {} \;

print "\nSpace Summary\n+++++++++++++++\n"
df -Ph ${DEST}
PCTUSED=`df -Ph . | awk 'NR > 1 {print $5}' | sed 's/\%//'`
echo
if [[ ${PCTUSED} -gt ${THRESHOLD} ]]
then
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "WARNING: The mountpoint for ${DEST} is over ${THRESHOLD}% full!"
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
fi
echo

exit 0
  
