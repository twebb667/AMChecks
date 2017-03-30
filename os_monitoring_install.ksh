#!/bin/ksh
##################################################################################
# Name             : os_monitoring_install.ksh 
# Author           : Tony Webb
# Created          : 20 Jan 2016
# Type             : Korn shell script
# Version          : 010
# Parameters       : 
# Returns          : 0   Success
#                    50  Wrong parameters
# Notes            :
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 20/01/16 | T. Webb    | Original
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset EXTERNAL_TABLE_DIR=${AMCHECK_DIR}/external_tables
typeset TEMP_DIR=/tmp/amchecks

typeset THISSCRIPTNAME=`basename $0`

###################################################################################
# Set these variables before running 
# (or if you have security concerns unset these and you should be prompted).
###################################################################################
typeset REMOTE_HOST="YOUR_MONITORING_SERVER"
typeset REMOTE_PATH="/home/oracle/amchecks"
typeset REMOTE_PASSWORD="ssh_change_this_password"
typeset AMU_PASSWORD="change_this"

if [[ -z ${REMOTE_HOST} ]]
then
    print "Please enter the host to copy the script from (probably the same place where AMChecks is installed)."
    read REMOTE_HOST
fi

if [[ -z ${REMOTE_PATH} ]]
then
    print "Please enter the directory on ${REMOTE_HOST} where the script lives."
    read REMOTE_PATH
fi

if [[ -z ${REMOTE_PASSWORD} ]]
then
    print "Please enter the password for user oracle on ${REMOTE_HOST}."
    read REMOTE_PASSWORD
fi

if [[ -z ${AMU_PASSWORD} ]]
then
    print "Please enter the password for user amu (locally) ${AMU_PASSWORD}."
    read AMU_PASSWORD
fi

mkdir -p ${AMCHECK_DIR} 2>/dev/null
mkdir -p ${EXTERNAL_TABLE_DIR} 2>/dev/null
mkdir -p ${TEMP_DIR} 2>/dev/null

#cd ${AMCHECK_DIR}
#`ftp -n ${REMOTE_HOST} <<- FTP1
#quote USER oracle
#quote PASS ${REMOTE_PASSWORD}
#cd ${REMOTE_PATH}
#put os_space_check.ksh
#bye    
#quit
#FTP1`
#cd -

echo "${REMOTE_PASSWORD}" 
scp oracle@${REMOTE_HOST}:${REMOTE_PATH}/os_space_check.ksh ${AMCHECK_DIR}/.
chmod +x ${AMCHECK_DIR}/os_space_check.ksh

cat /etc/oratab | grep -v '#'

print "Please choose the local database for hosting the external table"

. oraenv

sqlplus -s '/ as sysdba' <<- SQL100 
	SET PAGES 0
	GRANT CREATE TABLE TO amu;
	CREATE DIRECTORY amcheck_dir AS '${EXTERNAL_TABLE_DIR}';
	GRANT ALL ON DIRECTORY amcheck_dir TO amu;
	exit;
SQL100

sqlplus -s amu/${AMU_PASSWORD} <<- SQL200
	SET PAGES 0
	CREATE TABLE AMU.AM_OS_SPACE_LOAD (
		SERVER          VARCHAR2(30 CHAR),
		FILESYSTEM      VARCHAR2(200 CHAR),
		SIZEK           NUMBER(10),
		USEDK           NUMBER(10),
		AVAILK          NUMBER(10),
		PCTUSED         NUMBER(3),
		MOUNTPOINT      VARCHAR2(200 CHAR),
		DF_DOW          VARCHAR2(10 CHAR),
		DF_TIMESTAMP    VARCHAR2(40 CHAR)
		)
	ORGANIZATION EXTERNAL
	(
		TYPE ORACLE_LOADER DEFAULT DIRECTORY AMCHECK_DIR ACCESS PARAMETERS
		(
			RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
			SKIP 0 FIELDS TERMINATED BY ', ' MISSING FIELD VALUES ARE NULL
		)
		LOCATION (AMCHECK_DIR: 'am_os_space_load.dbf')
	)
	REJECT LIMIT UNLIMITED;
	exit;
SQL200

print
print 'As user oracle add the following to cron:'
date
print "18        * * * *  ksh -c '${AMCHECK_DIR}/os_space_check.ksh 1> ${TEMP_DIR}/os_space_check_last_output 2>&1'"

print "Actually, change the cron so it runs while you wait (don't just run it from the command line)."
print "then check as amu by running the following in sqlplus:"
print
print "SELECT * FROM amu.am_os_space_load;"
print
print "If all looks good, correct the cron and put your feet up!"
print
print "Enable this once you are happy by running the following on the master AMChecks database as user amo:"
print
print "UPDATE am_database SET os_checks_ind = 'Y' WHERE ..whatever (update the record for the database chosen here)"

rm -f ${THISSCRIPTNAME}
exit 1

