#!/bin/ksh
##################################################################################
# Name             : reconcile.ksh
# Author           : Tony Webb
# Created          : 07 September 2016
# Type             : Korn shell script
# Version          : 010
# Parameters       : -d  database
#                    -m  (mail)
# Returns          : 0   Success
#                    50  Wrong parameters
#
# Notes            : Updates info in the AMChecks tables for the managed databases.
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 07/09/16 | T. Webb    | Original
##################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -a alternate_email -m (mail) -d database (defaults to all)"

typeset -u DATABASE
typeset EXTERNAL_DIR="${AMCHECK_DIR}/external_tables"
typeset LANG=en_GB
typeset LINE
typeset MAIL_BUFFER="${TEMP_DIR}/reconcile"
typeset MAIL_TITLE='Managed Database Reconciliation'
typeset MAIL_HEADER=`echo ${MAIL_TITLE} | sed 's/ /_/g'`
typeset SEND_MAIL='N'
typeset TEMPFILE1="${TEMP_DIR}/reconcile.lst"
typeset TEMPFILE2="${TEMP_DIR}/reconcile2.lst"
typeset TEMPFILE3="${TEMP_DIR}/reconcile3.lst"
typeset TNS_ADMIN=${TEMP_DIR}
export TNS_ADMIN

#############
# Functions
#############

function f_run
{
    typeset -l SID=$1
    typeset -u UC_SID=$1
    typeset START_DATE=`date +%d-%m-%y:%H.%M.%S`
    typeset STOP_DATE

    print "Retrieving DBID for ${UC_SID}" | tee -a ${MAIL_BUFFER}

sqlplus -s ${CONNECT}\@${SID} <<- SQL100 >> ${TEMPFILE1}
	SET PAGES 0
	SET LINES 90
	SET FEEDBACK OFF
	SET TAB OFF
	COL dbid FORMAT A24
	COL name FORMAT A24
	COL host_name FORMAT A30
	SELECT  RPAD('${UC_SID}',20) AS name,
		RPAD(TO_CHAR(dbid),20) AS DBID,
		TRIM(DECODE(SUBSTR(host_name, 1 ,INSTR(host_name, '.', 1, 1)-1), NULL, host_name, SUBSTR(host_name, 1 ,INSTR(host_name, '.', 1, 1)-1))) AS host_name
	FROM   v\$database , v\$instance;
	exit;
SQL100
}

#######
# Main
#######

# Read environments for the morning checks
. ${AMCHECK_DIR}/.amcheck

# Read standard amchecks functions
. ${AMCHECK_DIR}/functions.ksh

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!

while getopts a:d:m o
do      case "$o" in
        a)      MAIL_RECIPIENT="${OPTARG}"  
	        SEND_MAIL="Y";;
        d)      DATABASE="${OPTARG}";;
	m)      SEND_MAIL="Y";;
        [?])    print -- "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ $# -ne 0 ]]
then
    print -- "Error - please do not specify positional parameters. ${USAGE}"
    exit 50
fi

echo "Database Name            DBID                     HOST" > ${TEMPFILE3}
echo "=============            ====                     ==========================" >> ${TEMPFILE3}

rm -f ${TEMPFILE1}
rm -f ${MAIL_BUFFER}

if [[ ! -z ${DATABASE} ]]
then
	sqlplus -s ${AMCHECK_TNS} <<- SQL500 > ${TEMPFILE2}
	SET PAGES 0
	SET FEEDBACK OFF
		SELECT database_name || ' Host: ' || server || cluster_name
		FROM  (SELECT   d.database_name,
			CASE WHEN s.server = s.physical_server_abbrev
			THEN s.server
			ELSE s.server || ' (' || s.physical_server_abbrev || ')' END AS server,
			CASE WHEN s.cluster_name IS NULL
			THEN NULL
			ELSE ' [' || s.cluster_name || '] ' END AS cluster_name
		FROM    amo.am_database d,
			amo.am_server s
		WHERE   d.database_name='${DATABASE}'
		AND     d.server = s.server)
		exit;
SQL500
else
    sqlplus -s ${AMCHECK_TNS} <<- SQL600 > ${TEMPFILE2}
	SET PAGES 0
	SET FEEDBACK OFF
	SELECT database_name || ' Hosted on ' || server || cluster_name
	FROM  (SELECT   d.run_order,
			d.database_name,
			CASE WHEN s.server = s.physical_server_abbrev
			THEN s.server
			ELSE s.server || ' (' || s.physical_server_abbrev || ')' END AS server,
			CASE WHEN s.cluster_name IS NULL
			THEN NULL
			ELSE ' [' || s.cluster_name || '] ' END AS cluster_name
		FROM    amo.am_database d,
			amo.am_server s
		WHERE   d.database_name NOT IN (SELECT database_name
		FROM   amo.am_sidskip
		WHERE  sidskip_type IN ('DAILY', RTRIM(TO_CHAR(sysdate,'DAY')), RTRIM(TO_CHAR(sysdate,'DD')))
		AND    TO_DATE(NVL(date_from, sysdate),'DD-MM-YY') <= TO_DATE(sysdate,'DD-MM-YY')
		AND    TO_DATE(NVL(date_to, sysdate),'DD-MM-YY')   >= TO_DATE(sysdate,'DD-MM-YY')
		AND    TO_NUMBER(60*(NVL(hour_from,00))+TO_NUMBER(NVL(minute_from,00)))
			<= TO_NUMBER(60*(TO_CHAR(sysdate,'HH24'))+TO_NUMBER(TO_CHAR(sysdate,'MI')))
		AND    TO_NUMBER(60*(NVL(hour_to,23))+TO_NUMBER(NVL(minute_to,59)))
 			>= TO_NUMBER(60*(TO_CHAR(sysdate,'HH24'))+TO_NUMBER(TO_CHAR(sysdate,'MI')))
		AND    disabled <> 'Y')
		AND     d.disabled <> 'Y'
		AND     s.disabled <> 'Y'
		AND     d.server = s.server)
	ORDER BY run_order ASC, database_name ASC;
	exit;
SQL600

fi
cat ${TEMPFILE2} | sed '/^$/d' | while read SID
do
    f_run ${SID}
done

cat ${TEMPFILE1} >> ${TEMPFILE3} 
cat ${TEMPFILE1} | sed '/[  ][  ]*/s//\, /g ' > ${EXTERNAL_DIR}/am_os_reconcile_load.dbf

sqlplus -s ${AMCHECK_TNS} <<- SQL700 >> ${TEMPFILE3}
	SET PAGES 1000
	SET FEEDBACK OFF
	SET LINES 120
	COL host_name FORMAT A20
	prompt
	prompt The following duplicate DBIDs were found 
	prompt (it may be an empty list - if not look to use 'nid')
	prompt

	SELECT database_name, dbid, host_name FROM am_reconcile_load WHERE dbid IN (SELECT dbid FROM am_reconcile_load GROUP BY dbid HAVING COUNT(*) > 1) ORDER BY dbid;

	MERGE INTO amo.am_database a
	USING
	(SELECT l.database_name, x.server, l.dbid 
	 FROM   (SELECT database_name, host_name, dbid FROM am_reconcile_load) l,
		(SELECT d.database_name, s.physical_server_abbrev AS host_name, d.server FROM am_database d, am_server s WHERE d.server = s.server) x
	 WHERE  l.database_name = x.database_name
	 AND    l.host_name = x.host_name) b
--	ON (a.database_name = b.database_name AND a.server = b.host_name)
	ON (a.database_name = b.database_name AND a.server = b.server)
	WHEN MATCHED THEN
	UPDATE SET a.dbid = b.dbid;
	exit;
SQL700


if [[ ${SEND_MAIL} == "Y" ]]
then
    f_mail ${MAIL_HEADER}  blue ${MAIL_RECIPIENT} "${TEMPFILE3}[courier]+${MAIL_BUFFER}[Arial]" ${MAIL_TITLE}
fi

exit 0

