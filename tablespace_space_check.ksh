#!/bin/ksh
##################################################################################
# Name             : tablespace_space_check.ksh
# Author           : Tony Webb
# Created          : 24 Devember 2015
# Type             : Korn shell script
# Version          : 030
# Parameters       : -a  address (alternative e-mail address)
#                    -c  (cron mode)
#                    -d  database 
#                    -f  dow_number(s) 1,2,3,4,5,6,0 where Sun =0 e.g. 145
#                    -m  (mail)
# Returns          : 0   Success
#                    50  Wrong parameters
#
# Notes            : N.B. Multiple entries for the same day are not recorded (assuming the 
#                    NLS_DATE_FORMAT is set to dd-mm-yy or similar). 
#
#                    Note that you should specify the full domain name of the
#                    database if using the -d option (e.g. fred.world, not fred).
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 24/12/15 | T. Webb    | Original
# 020     | 17/05/16 | T. Webb    | Undo and Temp tablespaces added(ish)
# 030     | 18/05/16 | T. Webb    | Added -f parameter
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -c (cron mode) -m (mail) -d database (defaults to all) -f dow_number"

typeset CRON_MODE='N'
typeset DATABASE
typeset DOW=1
typeset DOW_NOW=`date '+%w'`
typeset EXTERNAL_DIR="${AMCHECK_DIR}/external_tables"
typeset LANG=en_GB
typeset LINE
typeset MAIL_BUFFER="${TEMP_DIR}/tablespace_space_check_mail"
typeset MAIL_TITLE='Tablespace Space Summary'
typeset SEND_MAIL='N'
typeset TEMPFILE1="${TEMP_DIR}/tablespace_space_check1.lst"
typeset TEMPFILE2="${TEMP_DIR}/tablespace_space_check2.lst"
typeset TEMPFILE3="${TEMP_DIR}/tablespace_space_check3.lst"
typeset TEMPFILE4="${TEMP_DIR}/tablespace_space_check4.lst"
typeset TEMPFILE5="${TEMP_DIR}/tablespace_space_check5.lst"
typeset TEMPFILE6="${TEMP_DIR}/tablespace_space_check6"
typeset TEMPFILE7="${TEMP_DIR}/tablespace_space_check7.lst"
typeset TNS_ADMIN=${TEMP_DIR}
export TNS_ADMIN
typeset -u UPDATE_MAIN='N'

#############
# Functions
#############

function f_run
{
    #########################################################
    # Populate the flatfile/datafile for the external tables
    #########################################################

    typeset -u SID=$1
    typeset START_DATE=`date +%d-%m-%y:%H.%M.%S`
    typeset STOP_DATE

    print -n -- "Processing ${SID}"

	sqlplus -s ${CONNECT}\@${SID} <<- SQL100 > ${TEMPFILE1}
	set pages 0
	set lines 200
	set feedback off
	SELECT  LOWER(v.host_name) || ', ' ||
		UPPER(d.name) || ', ' ||
                NVL(b.tablespace_name || DECODE(SUBSTR(t.contents,1,1),'T','(T)','U','(U)',''), NVL(a.tablespace_name,'UNKOWN')) || ', ' ||
		sysdate || ', ' ||
		TO_CHAR(mbytes_alloc) || ', ' ||
		TO_CHAR(mbytes_alloc-nvl(mbytes_free,0)) || ', ' ||
		TO_CHAR(NVL(mbytes_free,0))
	FROM (SELECT SUM(bytes)/1024/1024 AS Mbytes_free,
		MAX(bytes)/1024/1024 AS mb_largest,
		tablespace_name
		FROM   sys.dba_free_space
		GROUP BY tablespace_name ) a,
		dba_tablespaces t,
		(SELECT SUM(bytes)/1024/1024    AS Mbytes_alloc,
		SUM(GREATEST(maxbytes,bytes))/1024/1024 AS Mbytes_max,
		tablespace_name
		FROM   sys.dba_data_files
		GROUP BY tablespace_name
		UNION ALL
		SELECT SUM(bytes)/1024/1024    AS Mbytes_alloc,
		SUM(GREATEST(maxbytes,bytes))/1024/1024 AS Mbytes_max,
		tablespace_name
		FROM   sys.dba_temp_files
		GROUP BY tablespace_name )b,
		v\$database d,
		v\$instance v
	WHERE a.tablespace_name (+) = b.tablespace_name
	and   b.tablespace_name = t.tablespace_name
/
	exit;
SQL100


    cat ${TEMPFILE1} | sed '/^$/d' | grep ', ' | while read LINE
    do
        IFS=','
        set ${LINE}
        SERVER=${1}
        if [[ `echo ${SERVER} | grep -c '\.'` -gt 0 ]]
        then
            SERVER=`echo ${SERVER} | cut -d'.' -f1`
        fi
        SID=${2}
	TABLESPACE=${3}
        SPACE_TIME=${4}
        MEG_DATA=${5}
        MEG_FREE=${6}
        MEG_USED=${7}
	
        print -- "${SERVER}, ${SID}, ${TABLESPACE}, ${SPACE_TIME}, ${MEG_DATA}, ${MEG_USED}, ${MEG_FREE}" >> ${TEMPFILE6}
#debug
        print -- "${SERVER}, ${SID}, ${TABLESPACE}, ${SPACE_TIME}, ${MEG_DATA}, ${MEG_USED}, ${MEG_FREE}" 
    done
        
    sed 's/  / /g' < ${TEMPFILE6} > ${EXTERNAL_DIR}/am_tablespace_space_load.dbf
    
    STOP_DATE=`date +%d-%m-%y:%H.%M.%S`
    STOP_DAY=${STOP_DATE%%:*}
    STOP_SEC=`echo ${STOP_DATE##*:} | awk -F. '{ print ($1 *3600 ) + ( $2 * 60 ) + $3 }'`
    START_DAY=${START_DATE%%:*}
    START_SEC=`echo ${START_DATE##*:} | awk -F. '{ print ($1 *3600 ) + ( $2 * 60 ) + $3 }'`

    if [[ ${STOP_DAY} != ${START_DAY} ]]
    then
        #######################################################################################
        # assumes 1 day diff max i.e. job ran over midnight but took less than a day in total!
        #######################################################################################
        let "ELAPSED_SECONDS = ${STOP_SEC} - ${START_SEC} + 86400"
    else
        let "ELAPSED_SECONDS = ${STOP_SEC} - ${START_SEC}"
    fi
    print -- " - Completed in ${ELAPSED_SECONDS} Seconds"

}

#######
# Main
#######

# Read environments for the morning checks
. ${AMCHECK_DIR}/.amcheck

# Read standard amchecks functions
. ${AMCHECK_DIR}/functions.ksh

#ORAENV_ASK=NO
#ORACLE_SID=DOUERMT1
#. oraenv

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!

while getopts a:cd:f:m o
do      case "$o" in
        a)      MAIL_RECIPIENT="${OPTARG}"  
	        SEND_MAIL="Y";;
        c)      CRON_MODE="Y";;
        d)      DATABASE="${OPTARG}";;
        f)      DOW="${OPTARG}";;
	m)      SEND_MAIL="Y";;
        [?])    print -- "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 0 ]]
then
   if [[ ${CRON_MODE} = 'Y' ]]
   then 
        print -- "Error - please do not specify positional parameters."
   else
        f_redprint "Error - please do not specify positional parameters"
   fi
   exit 50
fi

if [[ `echo ${DOW} | grep -c ${DOW_NOW}` -gt 0 ]]
then
    UPDATE_MAIN='Y'
fi

EXTERNAL_DIR=~oracle/amchecks/external_tables
    
if [[ ! -d ${EXTERNAL_DIR} ]]
then
   mkdir ${EXTERNAL_DIR}
fi

# Header. External table definition needs to 'skip 2'
print -- "SERVER, DATABASE_NAME,TABLESPACE,  SPACE_TIME, MEG_DATA, MEG_FREE, MEG_USED" > ${TEMPFILE6}
print -- "--------------------------------------------------------------------------------------" >> ${TEMPFILE6}

if [[ ! -z ${DATABASE} ]]
then
    f_run ${DATABASE}
else
	sqlplus -s ${AMCHECK_TNS} <<- SQL500 > ${TEMPFILE2}
	SET PAGES 0
	SET FEEDBACK OFF
	SELECT database_name FROM amo.am_database WHERE disabled <> 'Y' ORDER BY 1;
	exit;
SQL500
    cat ${TEMPFILE2} | sed '/^$/d' | while read SID
    do
        f_run ${SID}
    done
fi
sqlplus -s ${AMCHECK_TNS} <<- SQL550 > ${TEMPFILE7}
	SET PAGES 0
	SET FEEDBACK OFF
	SET TAB OFF
	MERGE INTO amo.am_tablespace_month_space a
	USING
	(SELECT distinct database_name, server, tablespace_name, space_time, meg_data, meg_free, meg_used, meg_temp FROM am_tablespace_space_load) b
	ON (a.database_name = b.database_name AND a.server = b.server AND a.tablespace_name = b.tablespace_name AND a.space_time = b.space_time)
	WHEN MATCHED THEN
	UPDATE SET a.meg_data = b.meg_data, a.meg_free = b.meg_free, a.meg_used = b.meg_used, a.meg_temp = b.meg_temp
	WHEN NOT MATCHED THEN
	INSERT (a.database_name, a.server, a.tablespace_name, a.space_time, a.meg_data, a.meg_free, a.meg_used, a.meg_temp)
	VALUES (b.database_name, b.server, b.tablespace_name, b.space_time, b.meg_data, b.meg_free, b.meg_used, b.meg_temp);
--	DELETE FROM amo.am_tablespace_month_space where space_time < sysdate -32;
	exit;
SQL550

#echo "Debug: UPDATE_MAIN is $UPDATE_MAIN"
if [[ ${UPDATE_MAIN} == 'Y' ]]
then
    echo "Updating main space table"
	sqlplus -s ${AMCHECK_TNS} <<- SQL600 > ${TEMPFILE3}
	SET PAGES 0
	SET FEEDBACK OFF
	SET TAB OFF
	MERGE INTO amo.am_tablespace_space a
	USING
	(SELECT distinct database_name, server, tablespace_name, space_time, meg_data, meg_free, meg_used, meg_temp FROM am_tablespace_space_load) b
	ON (a.database_name = b.database_name AND a.server = b.server AND a.tablespace_name = b.tablespace_name AND a.space_time = b.space_time)
	WHEN MATCHED THEN
	UPDATE SET a.meg_data = b.meg_data, a.meg_free = b.meg_free, a.meg_used = b.meg_used, a.meg_temp = b.meg_temp
	WHEN NOT MATCHED THEN
	INSERT (a.database_name, a.server, a.tablespace_name, a.space_time, a.meg_data, a.meg_free, a.meg_used, a.meg_temp)
	VALUES (b.database_name, b.server, b.tablespace_name, b.space_time, b.meg_data, b.meg_free, b.meg_used, b.meg_temp);
	SPOOL ${TEMPFILE4}
	start ${AMCHECK_DIR}/tablespace_growth_report ${DATABASE}
	exit;
SQL600
else
    echo "NOT Updating main space table"
fi

if [[ ${SEND_MAIL} == "Y" ]] && [[ ${UPDATE_MAIN} == 'Y' ]]
then
  echo "Please see attached.." > ${MAIL_BUFFER}
   
  cp ${TEMPFILE4} ${TEMPFILE5}
  sed 's/\.\./\&nbsp\&nbsp/g' < ${TEMPFILE5} > ${TEMPFILE4}
  sed 's/\. /  /g' < ${TEMPFILE4} > ${TEMPFILE5}
  sed 's/ \./  /g' < ${TEMPFILE5} > ${TEMPFILE4}
  sed -e 's/\([.]\)\([A-Za-z]\)/ \2/g' < ${TEMPFILE4} > ${TEMPFILE5}

  f_mail Tablespace_Space_Summary blue "${MAIL_RECIPIENT}" "${TEMPFILE5}[courier]+${MAIL_BUFFER}[Arial]" ${MAIL_TITLE}
fi
rm -f ${TEMPFILE3}
rm -f ${TEMPFILE4}
exit 0

