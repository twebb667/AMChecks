#!/bin/ksh
##################################################################################
# Name             : total_space_check.ksh
# Author           : Tony Webb
# Created          : 26 May 2015
# Type             : Korn shell script
# Version          : 040
# Parameters       : -a  address (alternative e-mail address)
#                    -c  (cron mode)
#                    -d  database 
#                    -m  (mail)
# Returns          : 0   Success
#                    50  Wrong parameters
#
# Notes            : This is not currently designed to be a fine grained space 
#                    system. Tablespace level details are NOT captured and
#                    multiple entries for the same day are not recorded (assuming
#                    the NLS_DATE_FORMAT is set to dd-mm-yy or similar). This is 
#                    intended to be light-weight after all.
#
#                    Note that you should specify the full domain name of the
#                    database if using the -d option (e.g. fred.world, not fred).
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 26/05/15 | T. Webb    | Original
# 020     | 18/06/15 | T. Webb    | Mail options (m and a) added
# 030     | 03/07/15 | T. Webb    | Changed to sql being called
# 040     | 07/09/15 | T. Webb    | Timings added (similar to logic in 
#         |          |            | is_oracle_ok.ksh)
##################################################################################

# To change this to include tablespace details add in something based on this:
#
#SELECT NVL(b.tablespace_name, NVL(a.tablespace_name,'UNKOWN')) AS tablespace,
#           mbytes_alloc AS total_mb,
#           mbytes_alloc-nvl(mbytes_free,0) AS used_mb,
#           NVL(mbytes_free,0) free_mb
#    FROM (SELECT SUM(bytes)/1024/1024 AS Mbytes_free,
#                 MAX(bytes)/1024/1024 AS mb_largest,
#                tablespace_name
#         FROM   sys.dba_free_space
#         GROUP BY tablespace_name ) a,
#        (SELECT SUM(bytes)/1024/1024    AS Mbytes_alloc,
#                SUM(GREATEST(maxbytes,bytes))/1024/1024 AS Mbytes_max,
#                tablespace_name
#         FROM   sys.dba_data_files
#         GROUP BY tablespace_name
#         UNION ALL
#         SELECT SUM(bytes)/1024/1024    AS Mbytes_alloc,
#                SUM(GREATEST(maxbytes,bytes))/1024/1024 AS Mbytes_max,
#                tablespace_name
#         FROM   sys.dba_temp_files
#         GROUP BY tablespace_name )b
#         WHERE a.tablespace_name (+) = b.tablespace_name;
#

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environments for the morning checks
. ${AMCHECK_DIR}/.amcheck
# Read standard amchecks functions
. ${AMCHECK_DIR}/functions.ksh

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -c (cron mode) -m (mail) -d database (defaults to all)"

typeset CRON_MODE='N'
typeset DATABASE
typeset EXTERNAL_DIR="${AMCHECK_DIR}/external_tables"
typeset GROWTH_PARAMETER="ALL"
typeset LANG=en_GB
typeset LINE
typeset MAIL_BUFFER="${TEMP_DIR}/total_space_check_mail"
typeset MAIL_TITLE='Space Check Summary'
typeset SEND_MAIL='N'
typeset TEMPFILE1="${TEMP_DIR}/total_space_check1.lst"
typeset TEMPFILE2="${TEMP_DIR}/total_space_check2.lst"
typeset TEMPFILE3="${TEMP_DIR}/total_space_check3.lst"
typeset TEMPFILE4="${TEMP_DIR}/total_space_check4.lst"
typeset TNS_ADMIN=${TEMP_DIR}
export TNS_ADMIN

#############
# Functions
#############

function f_run
{
    #########################################################
    # Populate the flatfile/datafile for the external tables
    #########################################################

    typeset -l SID=$1
    typeset -u UC_SID=$1
    typeset START_DATE=`date +%d-%m-%y:%H.%M.%S`
    typeset STOP_DATE

    print -n -- "Processing ${UC_SID}"

    sqlplus -s ${CONNECT}\@${SID} <<- SQL100 > ${TEMPFILE1}
	set pages 0
	set lines 200
	set feedback off
	SELECT  LOWER(v.host_name) || ', ' || 
		sysdate || ', ' || 
		NVL(SUM(d.data_gig),0) || ', ' || 
		NVL(SUM(f.free_gig),0) || ', ' || 
		NVL((SUM(d.data_gig) - SUM(f.free_gig)),0) || ', ' ||
		NVL(SUM(t.temp_gig),0) 
	FROM    (SELECT SUM(bytes)/1024/1024/1024 AS data_gig FROM dba_data_files) d, 
		(SELECT SUM(bytes)/1024/1024/1024 AS temp_gig FROM dba_temp_files) t, 
		(SELECT SUM(bytes)/1024/1024/1024 AS free_gig FROM dba_free_space) f,
		v\$instance v
	GROUP BY host_name
	ORDER BY 1;
    	exit;
SQL100

    cat ${TEMPFILE1} | sed '/^$/d' | grep ', ' | while read LINE
    do
        set ${LINE}
        SERVER=${1}
        # Next bit is to put back the comma that the cut removes when it strips out the domain from the server name
        if [[ `echo ${SERVER} | grep -c '\.'` -gt 0 ]]
        then
            SERVER=`echo ${SERVER} | cut -d'.' -f1`
            SERVER="${SERVER},"
        fi
        SPACE_TIME=${2}
        GIG_DATA=${3}
        GIG_FREE=${4}
        GIG_USED=${5}
        GIG_TEMP=${6}
	
        print -- "${UC_SID}, ${SERVER} ${SPACE_TIME} ${GIG_DATA} ${GIG_FREE} ${GIG_USED} ${GIG_TEMP}" >> ${EXTERNAL_DIR}/am_total_space_load.dbf
    done
    
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

# Read standard amchecks functions
#. ~oracle/amchecks/functions.ksh
. ${AMCHECK_DIR}/functions.ksh

#ORAENV_ASK=NO
#ORACLE_SID=DOUERMT1
#. oraenv

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!

while getopts a:cd:m o
do      case "$o" in
        a)      MAIL_RECIPIENT="${OPTARG}"  
	        SEND_MAIL="Y";;
        c)      CRON_MODE="Y";;
        d)      DATABASE="${OPTARG}"
		GROWTH_PARAMETER="${OPTARG}";;
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

EXTERNAL_DIR=~oracle/amchecks/external_tables
    
if [[ ! -d ${EXTERNAL_DIR} ]]
then
   mkdir ${EXTERNAL_DIR}
fi

# Header. External table definition needs to 'skip 2'
print -- "DATABASE_NAME,  SERVER, SPACE_TIME, GIG_DATA, GIG_FREE, GIG_USED, GIG_TEMP" > ${EXTERNAL_DIR}/am_total_space_load.dbf
print -- "--------------------------------------------------------------------------" >> ${EXTERNAL_DIR}/am_total_space_load.dbf

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
	sqlplus -s ${AMCHECK_TNS} <<- SQL600 > ${TEMPFILE3}
	SET PAGES 0
	SET FEEDBACK OFF
	SET TAB OFF
	MERGE INTO amo.am_total_space a
	USING
	(SELECT database_name, server, space_time, gig_data, gig_free, gig_used, gig_temp FROM am_total_space_load) b
	ON (a.database_name = b.database_name AND a.server = b.server AND a.space_time = b.space_time)
	WHEN MATCHED THEN
		UPDATE SET a.gig_data = b.gig_data, a.gig_free = b.gig_free, a.gig_used = b.gig_used, a.gig_temp = b.gig_temp
	WHEN NOT MATCHED THEN
		INSERT (a.database_name, a.server, a.space_time, a.gig_data, a.gig_free, a.gig_used, a.gig_temp)
		VALUES (b.database_name, b.server, b.space_time, b.gig_data, b.gig_free, b.gig_used, b.gig_temp);
	SPOOL ${TEMPFILE4}
--	start ${AMCHECK_DIR}/growth.sql ${GROWTH_PARAMETER} 31
	start ${AMCHECK_DIR}/growth_report ${GROWTH_PARAMETER}
	SPOOL OFF
	exit;
SQL600

if [[ ${SEND_MAIL} == "Y" ]]
then
  echo "Please see attached.." > ${MAIL_BUFFER}
#  f_mail Space_Summary blue "webb.t@cambridgeassessment.org.uk" "${TEMPFILE4}(snow)+${MAIL_BUFFER}(ghostwhite)" ${MAIL_TITLE}
#  f_mail Space_Summary blue "webb.t@cambridgeassessment.org.uk" "${TEMPFILE4}+${MAIL_BUFFER}" ${MAIL_TITLE}
#  f_mail Space_Summary blue "webb.t@cambridgeassessment.org.uk" 'null'+${TEMPFILE4} ${MAIL_TITLE}
#  f_mail Space_Summary blue ${MAIL_RECIPIENT} 'null'+${TEMPFILE4} ${MAIL_TITLE}
#  f_mail Space_Summary blue ${MAIL_RECIPIENT} "${TEMPFILE4}+${MAIL_BUFFER}" ${MAIL_TITLE}

  f_mail Space_Summary blue ${MAIL_RECIPIENT} "${TEMPFILE4}[courier]+${MAIL_BUFFER}[Arial]" ${MAIL_TITLE}
fi
exit 0

