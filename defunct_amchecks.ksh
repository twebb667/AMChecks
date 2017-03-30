#!/bin/ksh
##################################################################################
# Name             : amchecks.ksh
# Author           : Tony Webb
# Created          : 28 May 2014
# Type             : Korn shell script
# Version          : 520
# Parameters       : -a alternative e-mail
#                    -A e-mail common_file (for an additional summary e-mail)
#                       append an '+print' to the file name to print and delete it.                       
#                    -b (brief/terse)
#                    -c (cron mode)
#                    -C (no timiings)
#                    -d database (specific database)
#                    -D disable database title
#                    -h heading (override e-mail heading/title)
#                    -H (Replace heading graphic with text)
#                    -j script_id (job/script_set. Do not supply -s parameter)
#                    -k inline background colour (only applicable for e-mails)
#                    -K attachment background colour (only applicable for e-mails)
#                    -m (mail)
#                    -s script (sql to run)
#                    -S (summary mode)
#                    -t script_type 
#                    -T (use tnsnames)
#                    -x (extreme!)
#                    indicator_columns
#
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  Environment problems
#                    54  Missing files
#                    59  File permission problems
#
# Notes            : Database listing is taken from a list of databases in
#                    the database specified in .amcheck unless the '-t' option is used.
#                    Note that the sidskip file is only used with the tnsnames option.
#
#                    Consider use of the -b flag with your -s option.
#                    the -b flag prints the SID without a carriage return for each 
#                    database.
#
#                    Note that -S tends to work well with some reports (e.g. 
#                    the outout produced with '-e' but others may not be that
#                    readable! 
#
#                    Use qouble-quotes to delimit your e-mail heading (-h)
#
#                    If using the -D option you probably want to ensure that database name
#                    is displayed in some way. 
#
#                    Using -d with -j is permitted. This will 'replace' the database name
#                    for the script set with the database supplied via -d.
#
#                    Sample usage: 
#                    amchecks.ksh -c -m -T -a tony@wibble.com OCR_SUMMER_IND+Y
#                    amchecks.ksh -c -m -T -a tony@wibble.com -h "My Tests"
#                    amchecks.ksh -c -m OCR_SUMMER_IND+N
#                    amchecks.ksh -j TONY_SUMMARY -h "Tonys Special Report" -a "fred@flintstones.com" -d testdb
#
#---------+----------+------------+--------------------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+--------------------------------------------------------
# 010     | 28/05/14 | T. Webb    | Original
# 020     | 17/06/14 | T. Webb    | Functions moved to separate file
# 030     | 13/08/14 | T. Webb    | tsnnames and cron options added
# 040     | 13/08/14 | T. Webb    | Mail option added
# 050     | 18/08/14 | T. Webb    | Added notes to sidskip file
# 060     | 19/08/14 | T. Webb    | Added error check only option
# 070     | 27/08/14 | T. Webb    | Added in 'true space' dynamic scripts
# 080     | 23/12/14 | T. Webb    | Option to skip TEMP space errors
# 090     | 28/01/15 | T. Webb    | Changes to the -s option
# 100     | 05/04/15 | T. Webb    | Added some formatting information
# 110     | 24/04/15 | T. Webb    | Error highlighting changes for new space report
# 120     | 24/04/15 | T. Webb    | Added alternative e-mail option
# 130     | 28/04/15 | T. Webb    | Added indicator column filtering for targets
# 140     | 07/05/15 | T. Webb    | Added -h option
# 150     | 08/05/15 | T. Webb    | Added error/warning summary
# 160     | 11/05/15 | T. Webb    | More conditional highlighting
# 170     | 19/05/15 | T. Webb    | Added -S option
# 180     | 22/05/15 | T. Webb    | Added -k and -K options
# 190     | 27/05/15 | T. Webb    | UNDO tablespaces now handled similarly to TEMP
# 200     | 29/05/15 | T. Webb    | Removed dfspace/true_space checks (KISS)
#         |          |            | (possibly add back in later)
# 210     | 11/06/15 | T. Webb    | More info for tablespace space problems
# 220     | 10/12/15 | T. Webb    | Added version check and Amazon checks 
# 230     | 24/12/15 | T. Webb    | Excludes alerts for genuine temp and undo tablespaces
# 240     | 27/01/16 | T. Webb    | Added in more stats info via when_analyzed.sql
# 250     | 28/01/16 | T. Webb    | Moved script control to db tables
# 260     | 02/02/16 | T. Webb    | Support for script parameters (param1) added
# 270     | 02/02/16 | T. Webb    | Code tidy
# 280     | 02/02/16 | T. Webb    | Third version in 1 day! Nothing significant this time
# 290     | 03/02/16 | T. Webb    | More SCRIPTADD code changes
# 300     | 05/02/16 | T. Webb    | Better logic around running OS Checks and timings added
# 310     | 05/02/16 | T. Webb    | Added -H parameter
# 320     | 09/02/16 | T. Webb    | -e parameter changed to take a argument (oh no it wasnt)                    
# 330     | 10/02/16 | T. Webb    | Parameter flag changes plus checks for SCRIPT_TYPE (-t)
# 340     | 15/02/16 | T. Webb    | Sidskip code corrcted
# 350     | 16/02/16 | T. Webb    | html spaces tinkering
# 360     | 16/02/16 | T. Webb    | Formatting.
# 370     | 17/02/16 | T. Webb    | 'extreme' (extreme summary) flag added 
# 380     | 07/03/16 | T. Webb    | NOARCHIVELOG highlighted
# 390     | 07/03/16 | T. Webb    | Error count and warning count by database name
# 400     | 06/04/16 | T. Webb    | Changes when tnsnames.ora id copied (corrected).
# 410     | 22/04/16 | T. Webb    | Changes to -x checks (for RMAN)
# 420     | 19/05/16 | T. Webb    | Added in param2 support
# 430     | 09/06/16 | T. Webb    | Added -C and -D parameters
# 440     | 20/07/16 | T. Webb    | Added cluster info
# 450     | 10/08/16 | T. Webb    | Server and host combined on one line
# 460     | 06/09/16 | T. Webb    | Physical_server_abbrev added
# 470     | 20/09/16 | T. Webb    | Changes to RUN_ON_MASTER parameter
# 480     | 08/11/16 | T. Webb    | Added script sets (output to 1 e-mail)
# 490     | 10/11/16 | T. Webb    | Added -A option
# 500     | 14/13/16 | T. Webb    | Added more param1/param2 supported values
# 510     | 04/01/17 | T. Webb    | -f flag added
# 520     | 06/01/17 | T. Webb    | Added ERROR to individual script runs if applicable
#############################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

# Read environment variables for the morning checks
. ${AMCHECK_DIR}/.amcheck

# Read standard amchecks functions
. ${AMCHECK_DIR}/new_functions.ksh

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -s script -d database -D (disable db title) -c (cron mode) -C (disable timing) -f (disable feedback) -j script_id (script sets) -k (inline colour) -K (attachment colour) -T (use tnsnames) -a address (alternative e-mail) -b (brief) -t script_type -h header (new header) -H (change header graphic to text) -S (summary) -m (mail) -x (extreme) INDICATOR+Y"

typeset AMAZON_IND='N'
typeset ATTACHMENT_COLOUR=''
typeset BRIEF='N'
typeset CRON_MODE='N'
typeset DB_TITLE='Y'
typeset DBSID
typeset -i DBVERSION=101
typeset COLONSTRING # An awful name but I kind of got used to it!
typeset EDLINE
typeset -i ERRORCOUNT=0
typeset EXTREME='N'
typeset EXTREME_FILE="${TEMP_DIR}/amchecks_extreme.txt"
typeset FEEDBACK='Y'   
typeset HEADING_CHANGE='N'
typeset -u HOST
typeset -u INDCOLUMN
typeset INLINE_COLOUR=''
typeset LANG=en_GB
typeset MAIL_BUFFER="${TEMP_DIR}/amchecks_mail"
#typeset MAIL_RECIPIENT is set in external include file
typeset MAIL_HEADER
typeset MAIL_TITLE='Oracle AM Checks'
typeset MASTER_SCRIPTFILE="${TEMP_DIR}/master_scriptfile.sql"
typeset -u ONE_DB
typeset OUTPUT_BUFFER="${TEMP_DIR}/amchecks_output"
typeset OUTPUT_SUMMARY="${TEMP_DIR}/amchecks_summary"
typeset RMAN_CHECK
typeset -i RMAN_COUNT
typeset RMAN_SUMMARY
typeset -l SCRIPT
typeset -u SCRIPT_ID
typeset SCRIPT_STRING='Scripts'
typeset TIMING='Y'
typeset WHERE_SCRIPT_TYPE1=" AND s.script_type IN ('ALL', 'SUMMARY', 'CHECK')";
typeset WHERE_SCRIPT_TYPE2=" AND a.script_type IN ('ALL', 'SUMMARY', 'CHECK')";
typeset SCRIPTFILE="${TEMP_DIR}/scriptfile.sql"
typeset SCRIPT_TYPE="SUMMARY"
typeset SEND_MAIL='N'
typeset SID
typeset SIDSKIPFILE="${TEMP_DIR}/amchecks_sidskipfile.lst"
typeset SIDSKIP_NOTES
typeset -i SIDSKIP_TABLE_COUNT=0
typeset SIDSKIP_NOTES
typeset SPACE_PREP
typeset STATS_CHECK
typeset STATS_SUMMARY
typeset SUMMARY='N'
typeset SUMMARY_BUFFER="${TEMP_DIR}/amchecks_summary"
typeset SUMMARY_EMAIL
typeset SUMMARY_EMAIL_PRINT='N'

typeset -i TEMPCOUNT=0
typeset TEMPFILE1="${TEMP_DIR}/amchecks1.lst"
typeset TEMPFILE2="${TEMP_DIR}/amchecks2.lst"
typeset TEMPFILE3="${TEMP_DIR}/amchecks3.lst"
typeset TEMPFILE4="${TEMP_DIR}/amchecks4.txt"
typeset TEMPFILE5="${TEMP_DIR}/amchecks5.txt"
typeset TEMPFILE6="${TEMP_DIR}/amchecks6.txt"
typeset THISDB
typeset THIS_SERVER=`hostname -s`
typeset TNSNAMES
typeset TNS_ADMIN=${TEMP_DIR}
export TNS_ADMIN
typeset -i TSCOUNT=0
typeset -i TYPE_COUNT=0
typeset TYPE_SPECIFIED='N'
typeset USE_TNSNAMES='N'
typeset -i WARNINGCOUNT=0
typeset WHERE_ADDITION=' '
typeset -u YNIND

##################
# Local Functions
##################

##############
# Run scripts 
##############

function f_run    
{                  
    typeset SID=$1
    shift 1
    typeset -L80 SERVERTITLE=$*
    typeset -u UPPER_SID=${SID}

    typeset HOSTINFO
    typeset -i LEADER
    typeset LOCAL_SCRIPT
    typeset LOCAL_TITLE
    typeset ONELINETITLE
    typeset -L60 PRINT_SID="Running checks on ${UPPER_SID}"
    typeset SECOND_STRING
    typeset -i SID_ERRORCOUNT=0
    typeset -i SID_WARNINGCOUNT=0
    typeset START_DATE=`date +%d-%m-%y:%H.%M.%S`
    typeset START_DAY=${START_DATE%%:*}
    typeset -i START_SEC=`echo ${START_DATE##*:} | awk -F. '{ print ($1 *3600 ) + ( $2 * 60 ) + $3 }'`
    typeset START_DATE
    typeset STOP_DATE
    typeset -i TITLELENGTH
    
    LOCAL_SCRIPT=`echo ${SID} | cut -d'+' -f2`
    LOCAL_TITLE=`echo ${SID} | cut -d'+' -f3- | tr '_' ' '`

    SID=`echo ${SID} | cut -d'+' -f1`
    if [[ ${SID} != ${LOCAL_SCRIPT} ]]
    then
        SCRIPT=${LOCAL_SCRIPT}
    fi

    if [[ ! -z ${ONE_DB} ]] && [[ ! -z ${SCRIPT_ID} ]]
    then
        ###########################################################################
        # Override usual database name with the one specified at the command line.
        ###########################################################################
        SID=${ONE_DB}
    fi
    
    if [[ ! -z ${SCRIPT_ID} ]]
    then
        PRINT_SID="Running checks on ${SID} - ${SCRIPT}"
    fi

#    echo "SID is ${SID}" 
#    echo "SCRIPT is ${SCRIPT}" 

    rm -f ${TEMPFILE2}

    ####################################################
    # Check to see if this database needs to be skipped
    ####################################################
    if [[ ${USE_TNSNAMES} != 'Y' ]]
    then
        ##########################################################################################
        # Determine if database should be skipped (we already know it's NOT disabled)
        ##########################################################################################
    	SIDSKIP_TABLE_COUNT=`sqlplus -s ${AMCHECK_TNS} <<- SQL005
	set pages 0
	set feedback off
	SELECT count(*) FROM all_tables WHERE owner = 'AMO' AND table_name = 'AM_SIDSKIP';
	exit;
SQL005
`
        if [[ ${SIDSKIP_TABLE_COUNT} -gt 0 ]]
        then
		SIDSKIP_NOTES=`sqlplus -s ${AMCHECK_TNS} <<- SQL010
		set pages 0
		set feedback off
		spool ${SIDSKIPFILE}
		SELECT database_name || ' ' || sidskip_notes
		FROM   amo.am_sidskip
		WHERE  sidskip_type IN ('DAILY', RTRIM(TO_CHAR(sysdate,'DAY')), RTRIM(TO_CHAR(sysdate,'DD')))
		AND    TO_DATE(NVL(date_from, sysdate),'DD-MM-YY') <= TO_DATE(sysdate,'DD-MM-YY')
		AND    TO_DATE(NVL(date_to, sysdate),'DD-MM-YY')   >= TO_DATE(sysdate,'DD-MM-YY')
		AND    TO_NUMBER(60*(NVL(hour_from,00))+TO_NUMBER(NVL(minute_from,00))) <= TO_NUMBER(60*(TO_CHAR(sysdate,'HH24'))+TO_NUMBER(TO_CHAR(sysdate,'MI')))
		AND    TO_NUMBER(60*(NVL(hour_to,23))+TO_NUMBER(NVL(minute_to,59)))     >= TO_NUMBER(60*(TO_CHAR(sysdate,'HH24'))+TO_NUMBER(TO_CHAR(sysdate,'MI')))
		AND    disabled <> 'Y'
		UNION ALL
		SELECT database_name || ' (skipped as database marked as disabled)'
		FROM  amo.am_database
		WHERE disabled = 'Y';
		spool off
		exit;
SQL010
`
            echo ${SIDSKIP_NOTES} > ${SIDSKIPFILE}
        else
            echo ' ' > ${SIDSKIP_NOTES} > ${SIDSKIPFILE}
        fi
    fi

    if [[ `grep -icw ^${SID} ${SIDSKIPFILE}` -gt 0 ]]
    then
        ###########
        # skipping
        ###########
        PRINT_SID="Not(!) ${PRINT_SID}"
    else
        ###############
        # Not skipping. 
        ###############
        HOSTINFO=`sqlplus -s ${CONNECT}\@${SID} <<- SQL004
		set pages 0
		set feedback off
		SELECT RTRIM(host_name) FROM v\\$instance;
		exit;
		SQL004
`
#        PRINT_SID="Running checks on ${UPPER_SID} (hosted on ${HOSTINFO})"
    fi
   
    if [[ -z ${SCRIPT_ID} ]]
    then 
        ONELINETITLE="${PRINT_SID} - ${SERVERTITLE}"
        TITLELENGTH=`echo ${ONELINETITLE} | wc -c`
        let "LEADER = ( 120 - ${TITLELENGTH} ) / 2"
        SERVERTITLE=` printf '%*s ' ${LEADER} ' ' ; print ${ONELINETITLE} `
    else
        SERVERTITLE="${PRINT_SID}"
    fi

    if [[ ${DB_TITLE} == 'Y' ]]
    then
        if [[ ${BRIEF} == 'N' ]]
        then
            f_greenprint "\n                          ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"  >> ${OUTPUT_BUFFER}
            f_greenprint "                          + ${SERVERTITLE} +" >> ${OUTPUT_BUFFER}
            f_greenprint "                          ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n" >> ${OUTPUT_BUFFER}
            f_blueboldhtml "\n" >> ${MAIL_BUFFER}
            f_blueboldhtml "                   ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> ${MAIL_BUFFER}
            f_blueboldhtml "                   + ${SERVERTITLE} +" >> ${MAIL_BUFFER} 
            f_blueboldhtml "                   ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n" >> ${MAIL_BUFFER} 
    
            if [[ ! -z ${LOCAL_TITLE} ]]
            then
                f_greenprint "${LOCAL_TITLE}\n" >> ${OUTPUT_BUFFER}
                f_blueboldhtml "${LOCAL_TITLE}\n" >> ${MAIL_BUFFER}
            fi

        elif [[ ${BRIEF} == 'Y' ]]
        then
            printf '%s' "${SERVERTITLE}: " >> ${OUTPUT_BUFFER} 
            printf '%s' "${SERVERTITLE}: " >> ${MAIL_BUFFER} 
        fi
    fi
        
    if [[ `grep -icw ^${SID} ${SIDSKIPFILE}` -gt 0 ]]
    then
        ###########
        # skipping
        ###########
        SIDSKIP_NOTES=`grep -iw ^${SID} ${SIDSKIPFILE} | cut -d' ' -f2-`
        if [[ -z ${SIDSKIP_NOTES} ]]
        then
            SIDSKIP_NOTES=''
        else
            SIDSKIP_NOTES=`print "(${SIDSKIP_NOTES})" |  tr -s ' ' | sed 's/ )/)/'`
        fi
        if [[ ${CRON_MODE} == 'N' ]]
        then
            f_yellowprint "Intentionally skipped ${SIDSKIP_NOTES}" >> ${OUTPUT_BUFFER}
        else
            print -- "Intentionally skipped ${SIDSKIP_NOTES}" >> ${OUTPUT_BUFFER}
        fi
        f_greenboldhtml "Intentionally skipped ${SIDSKIP_NOTES}" >> ${MAIL_BUFFER}
    else
        ###############
        # Not skipping. 
        ###############

        # Dont bother trying to connect if you can't tnsping
        ${TNSPING} ${SID} 1 >/dev/null 2>&1
        RET=$?
        if [[ ${RET} -ne 0 ]]
        then
            if [[ ${CRON_MODE} == 'N' ]]
            then
                 f_redprint "Error running tnsping (${TNSPING}) on ${SID}"  >> ${OUTPUT_BUFFER}
            else
                 print -- "Error running ${TNSPING} on ${SID}"  >> ${OUTPUT_BUFFER}
            fi
            f_redboldhtml "Error running tnsping (${TNSPING}) on ${SID}"  >> ${MAIL_BUFFER}
        else
            if [[ ! -z ${SCRIPT} ]]
            then
                echo "start ${AMCHECK_DIR}/${SCRIPT}" > ${SCRIPTFILE}
                RET=$?
            elif [[ ${USE_TNSNAMES} == 'Y' ]]
            then
                cat > ${SCRIPTFILE} <<- SQLCOMMANDS
		start ${AMCHECK_DIR}/instance_summary.sql
		start ${AMCHECK_DIR}/redo_summary.sql
SQLCOMMANDS
                RET=$?
            else
                #####################################################################################################
                # Let's connect to the target database to get information that will affect which scripts are called
                # We need to get db version as this will affect what scripts we can call!
                # We also need to determine if database is on Amazon rds (check host name)
                # N.B. Double escape(!) needed.
                #####################################################################################################

		DBSID=${SID}
	    	COLONSTRING=`sqlplus -s ${CONNECT}\@${SID} <<- SQL006
		set pages 0
		set lines 130
		set feedback off
		SELECT SUBSTR(i.version,0,INSTR(i.version,'.')-1) || SUBSTR(i.version,INSTR(i.version,'.')+1,1) || ':' || 
			UPPER(NVL(SUBSTR(i.host_name,0,INSTR(i.host_name,'.')-1), i.host_name)) || ':' ||
			UPPER(d.name)
		FROM    v\\$instance i,
			v\\$database d;
		exit;
		SQL006
`
		DBVERSION=${COLONSTRING%%:*}
		HOST=`echo ${COLONSTRING} | cut -d':' -f2`
		DBSID=`echo ${COLONSTRING} | cut -d':' -f3`
                ############################################################################################
                # We have what we need from the target database to determine which scripts need to be run:
                # Note that an entry in am_sciptadd will cause the disabled flag in am_scripts to be ignored.
                ############################################################################################
		sqlplus -s -L ${AMCHECK_TNS} <<- SQL007 >${TEMPFILE1} 2>&1
		set pages 0
		set feedback off
		set heading off
		SPOOL ${SCRIPTFILE}
		SELECT 'start ${AMCHECK_DIR}/' || script_name
		FROM   (SELECT s.script_name || ' ' || param1  || ' ' || param2 AS script_name,
			       s.run_order
			FROM   amo.am_scripts s
			WHERE  s.frequency LIKE '%D%'
			${WHERE_SCRIPT_TYPE1}
			AND    s.run_on_master = 'N'
			AND    s.disabled <> 'Y'
			AND NOT EXISTS (SELECT 1
				FROM  amo.am_scriptskip k
				WHERE k.script_id = s.script_id
				AND   k.database_name = UPPER('${SID}')
				AND   k.disabled <> 'Y'
				AND   NVL(k.skipped_from,SYSDATE) <= sysdate
				AND   NVL(k.skipped_to,SYSDATE) >= sysdate)
			AND NVL(s.db_version_from,0) <= ${DBVERSION}
			AND NVL(s.db_version_to,999) >= ${DBVERSION}
			UNION
			SELECT s.script_name || ' ' || param1 || ' ' || param2, 
			       a.run_order
			FROM   amo.am_scripts s,
		       	       amo.am_scriptadd a	
			WHERE  a.frequency LIKE '%D%'
			${WHERE_SCRIPT_TYPE2}
			AND    a.script_id = s.script_id
			AND    a.database_name = UPPER('${SID}')
			AND    NVL(a.added_from,SYSDATE) <= sysdate
			AND    NVL(a.added_to,SYSDATE) >= sysdate
			AND    s.run_on_master = 'N'
			AND    a.disabled <> 'Y'
			AND NOT EXISTS (SELECT 1
				FROM  amo.am_scriptskip k
				WHERE k.script_id = s.script_id
				AND   k.database_name = UPPER('${SID}')
				AND   k.disabled <> 'Y'
				AND   NVL(k.skipped_from,SYSDATE) <= sysdate
				AND   NVL(k.skipped_to,SYSDATE) >= sysdate))
		ORDER BY run_order ASC;
		SPOOL OFF

		SPOOL ${MASTER_SCRIPTFILE}
		SELECT 'start ${AMCHECK_DIR}/' || script_name
		FROM   (SELECT s.script_name || ' ' || param1  || ' ' || param2 AS script_name,
			       s.run_order
			FROM   amo.am_scripts s
			WHERE  s.frequency LIKE '%D%'
			${WHERE_SCRIPT_TYPE1}
			AND    s.run_on_master = 'Y'
			AND    s.disabled <> 'Y'
			AND NOT EXISTS (SELECT 1
				FROM  amo.am_scriptskip k
				WHERE k.script_id = s.script_id
				AND   k.database_name = UPPER('${SID}')
				AND   k.disabled <> 'Y'
				AND   NVL(k.skipped_from,SYSDATE) <= sysdate
				AND   NVL(k.skipped_to,SYSDATE) >= sysdate)
			AND NVL(s.db_version_from,0) <= ${DBVERSION}
			AND NVL(s.db_version_to,999) >= ${DBVERSION}
			UNION
			SELECT s.script_name || ' ' || param1 || ' ' || param2, 
			       a.run_order
			FROM   amo.am_scripts s,
		       	       amo.am_scriptadd a	
			WHERE  a.frequency LIKE '%D%'
			${WHERE_SCRIPT_TYPE2}
			AND    a.script_id = s.script_id
			AND    a.database_name = UPPER('${SID}')
			AND    NVL(a.added_from,SYSDATE) <= sysdate
			AND    NVL(a.added_to,SYSDATE) >= sysdate
			AND    s.run_on_master = 'Y'
			AND    a.disabled <> 'Y'
			AND NOT EXISTS (SELECT 1
				FROM  amo.am_scriptskip k
				WHERE k.script_id = s.script_id
				AND   k.database_name = UPPER('${SID}')
				AND   k.disabled <> 'Y'
				AND   NVL(k.skipped_from,SYSDATE) <= sysdate
				AND   NVL(k.skipped_to,SYSDATE) >= sysdate))
		ORDER BY run_order ASC;
		SPOOL OFF
		exit;
		SQL007
		echo prompt >> ${MASTER_SCRIPTFILE}
               	RET=$?
            fi
            #####################################################################
            # Check that commands were written to command file OK. Run it if OK.
            #####################################################################

            if [[ ${RET} -ne 0 ]]
            then
                if [[ ${CRON_MODE} == 'N' ]]
                then
                     f_redprint "Error writing to script file"  >> ${OUTPUT_BUFFER}
                else
                     print -- "Error writing to script file"  >> ${OUTPUT_BUFFER}
                fi
                f_redboldhtml "Error writing to script filer"  >> ${MAIL_BUFFER}
                exit 59
            fi
            ########################################################################
            # substitute any param1/param2 values with possible matches(!)
	    #                                              
            # supported parameters: DBNAME (database name as it is in am_database)
            #                       SERVER (server name from target's v$instance)
            #                       SID    (idatabase name in target's v$database)
            #
            ########################################################################
            mv ${SCRIPTFILE} ${TEMPFILE2}
            cat ${TEMPFILE2} | sed s/DBNAME/${SID}/ | sed s/SERVER/${HOST}/ | sed s/SID/${DBSID}/ > ${SCRIPTFILE}

            if [[ -f ${MASTER_SCRIPTFILE} ]]
            then 
                mv ${MASTER_SCRIPTFILE} ${TEMPFILE2}
                cat ${TEMPFILE2} | sed s/DBNAME/${SID}/  | sed s/SERVER/${HOST}/ | sed s/SID/${DBSID}/ > ${MASTER_SCRIPTFILE}
            fi

            if [[ ! -s ${MASTER_SCRIPTFILE} ]]
            then
                echo > ${MASTER_SCRIPTFILE}
            fi

            if [[ ! -z ${SCRIPTFILE} ]] && [[ -f ${SCRIPTFILE} ]]
            then
		sqlplus -s -L ${CONNECT}\@${SID} <<- SQL10 >${TEMPFILE2} 2>&1
		set pages 0
		set feedback off
		start ${SCRIPTFILE}
		exit;
		SQL10
                RET=$?

                if [[ -z ${SCRIPT} ]] 
                then
			sqlplus -s -L ${AMCHECK_TNS} <<- SQL12 >>${TEMPFILE2} 2>&1
			set pages 0
			set lines 140
			set feedback off
			set heading off
                	start ${MASTER_SCRIPTFILE}
			SELECT 'The following scripts were skipped: ' || 
				LISTAGG(z.script_id || '(' || z.script_type || ')', ', ') 
			WITHIN GROUP (ORDER BY s.script_id) 
			FROM  amo.am_scriptskip s,
		      	amo.am_scripts z
			WHERE s.disabled <> 'Y'
			AND   s.database_name = UPPER('${SID}')
			AND   z.script_id = s.script_id 
			AND NOT EXISTS (SELECT 1 
					FROM   amo.am_scriptadd a 
					WHERE  a.disabled <> 'Y' 
					AND    a.database_name = s.database_name
					AND    NVL(a.added_from,SYSDATE) <= sysdate
					AND    NVL(a.added_to,SYSDATE) >= sysdate)
			GROUP BY s.database_name;
			exit;
			SQL12
                	RET=$?
	    	fi
	    fi

            if [[ `grep -c 'The following scripts were skipped:' ${TEMPFILE2}` -gt 0 ]]
            then
                echo ' ' >> ${TEMPFILE2}
            fi

            if [[ ${RET} -ne 0 ]] || [[ `grep -c 'ORA-' ${TEMPFILE2}` -gt 0 ]]
            then
                if [[ ${CRON_MODE} == 'N' ]]
                then
                    f_redprint "Error ${RET} running amchecks on ${SID}" >> ${OUTPUT_BUFFER}
                else
                    print -- "Error ${RET} running amchecks on ${SID}" >> ${OUTPUT_BUFFER}
                fi
                f_redboldhtml "Error ${RET} running amchecks on ${SID}" >> ${MAIL_BUFFER}
            else
                ############################################
                # Some output triggers subsequent checks...
                # A bit 'hard-codey' unfortunately.
                ############################################
                if [[ `grep -c 'ERROR - tablespace alerts' ${TEMPFILE2}` -gt 0 ]] && 
                   [[ `echo ${WHERE_SCRIPT_TYPE1} | grep -c 'CHECK'` -gt 0 ]] &&
                   [[ `echo ${WHERE_SCRIPT_TYPE1} | grep -c 'SUMMARY'` -eq 0 ]]
                then
			sqlplus -s -L ${CONNECT}\@${SID} <<- SQL20 >>${TEMPFILE2} 2>&1
			set pages 0
			start ${AMCHECK_DIR}/space_summary.sql '%' 90
			exit;
			SQL20
                fi
            fi
        fi

        STOP_DATE=`date +%d-%m-%y:%H.%M.%S`
        STOP_DAY=${STOP_DATE%%:*}
        STOP_SEC=`echo ${STOP_DATE##*:} | awk -F. '{ print ($1 *3600 ) + ( $2 * 60 ) + $3 }'`
        
        if [[ ${STOP_DAY} != ${START_DAY} ]]
        then
            #######################################################################################
            # assumes 1 day diff max i.e. job ran over midnight but took less than a day in total!
            #######################################################################################
            let "ELAPSED_SECONDS = ${STOP_SEC} - ${START_SEC} + 86400"
        else
            let "ELAPSED_SECONDS = ${STOP_SEC} - ${START_SEC}"
        fi

        if [[ ${ELAPSED_SECONDS} -eq 1 ]]
        then
            SECOND_STRING='Second'
        else
            SECOND_STRING='Seconds'
        fi

        #############################################################
        # Flag a problem if scripts took longer than 1 minute to run
        #############################################################
 
        if [[ ${FEEDBACK} == 'Y' ]]
        then
            if [[ ${TIMING} == 'Y' ]]
            then
                if [[ ${ELAPSED_SECONDS} -gt 60 ]]
                then
                    print -- "WARNING: ${SCRIPT_STRING} for ${SID} completed in ${ELAPSED_SECONDS} ${SECOND_STRING}" >> ${TEMPFILE2}
                else
                    print -- "${SCRIPT_STRING} for ${SID} completed in ${ELAPSED_SECONDS} ${SECOND_STRING}" >> ${TEMPFILE2}
       	        fi
            fi
        fi 

        ##############################################################
        # Highlight lines with 'ERROR, FAIL or very full tablespaces #
        ##############################################################
        OLD_IFS=${IFS}
        IFS="\$"
        export GREP_COLOR='01;31' # bold red

        cp ${TEMPFILE2} ${TEMPFILE5}

        if [[ ! -z ${ONE_DB} ]]
        then
            RMAN_COUNT=`grep -ic "No RMAN alerts for ${ONE_DB}" ${TEMPFILE5}`
        fi
        cat ${TEMPFILE2} | while read LINES
        do
            #############################################################################################################
            # Actually, we need to know when we have moved onto a new database or if we are only dealing with 1 database
            #############################################################################################################
            if [[ -z ${ONE_DB} ]] && [[ `print -- ${LINES} | grep -ic 'started on'` -gt 0 ]] 
            then
                THISDB=`print -- ${LINES} | cut -d' ' -f1`
                RMAN_COUNT=`grep -ic "No RMAN alerts for ${THISDB}" ${TEMPFILE5}`
            fi

            if [[ `print -- ${LINES} | grep '+' | grep -c 'Summary'` -gt 0 ]] 
            then
                ##############################
                # Highlight 'Summary' in BLUE
                ##############################
    
                f_blueprint ${LINES}  >> ${OUTPUT_BUFFER}
                f_boldhtml ${LINES}  >> ${MAIL_BUFFER}
    
            elif [[ `print -- ${LINES} | grep -c 'successes and failures'` -gt 0 ]]
            then
                ####################################################################
                # Catch matches that would otherwise be raised as 'false positives'
                ####################################################################

                f_blackhtml ${LINES} >> ${MAIL_BUFFER}
                print -- ${LINES}  >> ${OUTPUT_BUFFER}

            elif [[ `print -- ${LINES} | grep -c 'WARNING'` -gt 0 ]] 
            then
                #######################################################################
                # 'WARNING' will be from some 'CHECK' script. Highlight in GREEN.
                #######################################################################

                export GREP_COLOR='01;32' # bold yellow
                print -- ${LINES} | egrep -iw --color=always 'WARNING' >> ${OUTPUT_BUFFER}
                export GREP_COLOR='01;31' # bold red
                f_greenhtml ${LINES} >> ${MAIL_BUFFER}
                let SID_WARNINGCOUNT=SID_WARNINGCOUNT+1
    
            elif [[ `print -- ${LINES} | grep -c 'NOARCHIVELOG'` -gt 0 ]] 
            then
                #########################################################
                # NOARCHIVELOG is worth highlighting as a possible issue
                ##########################################################

                export GREP_COLOR='01;32' # bold yellow
                print -- ${LINES} | egrep -iw --color=always 'NOARCHIVELOG' >> ${OUTPUT_BUFFER}
                export GREP_COLOR='01;31' # bold red
                f_greenhtml ${LINES} >> ${MAIL_BUFFER}
                let SID_WARNINGCOUNT=SID_WARNINGCOUNT+1
    
            elif [[ `print -- ${LINES} | egrep '(u)|(t)' | egrep -ic '\[XXXXXXXXXXXXXXXXXX--\]$|\[XXXXXXXXXXXXXXXXXXX-\]$| \[XXXXXXXXXXXXXXXXXXXX\]$'` -gt 0 ]]
            then
                #######################################################################
                # TEMP and UNDO tablespaces that are 90%+ full
                # Highlight in Green and replace 'ERROR' text to read 'WARNING'!
                # Note that the maximum size is being checked here 
                # (remove the '$' to change this to check for current unextended size)
                #######################################################################

                EDLINE=`print ${LINES} | sed 's/ERROR/WARNING/'`
                export GREP_COLOR='01;32' # bold yellow
                print -- ${EDLINE} | egrep -iw --color=always 'ERROR|WARNING|XXXXXXXXXXXXXXXXXX|XXXXXXXXXXXXXXXXXXX|XXXXXXXXXXXXXXXXXXXX' >> ${OUTPUT_BUFFER}
                export GREP_COLOR='01;31' # bold red
                f_greenhtml ${EDLINE} >> ${MAIL_BUFFER}
                let SID_WARNINGCOUNT=SID_WARNINGCOUNT+1
    
            elif [[ `print -- ${LINES} | egrep -ic '\[XXXXXXXXXXXXXXXXXX--\]$|\[XXXXXXXXXXXXXXXXXXX-\]$| \[XXXXXXXXXXXXXXXXXXXX\]$'` -gt 0 ]]
            then
                ########################################################
                # Non-TEMP and Non-UNDO tablespaces that are 80%+ full
                # Highlight in Red                       
                ########################################################

                export GREP_COLOR='01;31' # bold red
                print -- ${LINES} | egrep -iw --color=always 'ERROR|XXXXXXXXXXXXXXXXXX|XXXXXXXXXXXXXXXXXXX|XXXXXXXXXXXXXXXXXXXX' >> ${OUTPUT_BUFFER}
                f_redhtml ${LINES} >> ${MAIL_BUFFER}
                let SID_ERRORCOUNT=SID_ERRORCOUNT+1

            elif [[ ${RMAN_COUNT} -gt 0 ]] && [[ `print -- ${LINES} | grep -ic 'backup failure'` -gt 0 ]]
            then
                ###############################################################################################################
                # Highlight RMAN errors but as no RMAN alerts have been detected we should highlight failures in green/yellow
                ###############################################################################################################
                export GREP_COLOR='01;32' # bold yellow
                print -- ${LINES} | egrep -iw --color=always 'ERROR|FAIL|FAILED' >> ${OUTPUT_BUFFER}
                export GREP_COLOR='01;31' # bold red
                f_greenhtml ${LINES} >> ${MAIL_BUFFER}
                let SID_WARNINGCOUNT=SID_WARNINGCOUNT+1
    
            elif [[ `print -- ${LINES} | egrep -ic 'ERROR|FAIL'` -gt 0 ]]
            then
                ####################
                # Remaining errors #
                ####################
    
                export GREP_COLOR='01;31' # bold red
                print -- ${LINES} | egrep -iw --color=always 'ERROR|FAIL|FAILED' >> ${OUTPUT_BUFFER}
                f_redhtml ${LINES} >> ${MAIL_BUFFER}
                let SID_ERRORCOUNT=SID_ERRORCOUNT+1
            else
                ###############################################
                # if you get here you don't need highlighting..
                ###############################################
    
                f_blackhtml ${LINES} >> ${MAIL_BUFFER} 
                print -- ${LINES}  >> ${OUTPUT_BUFFER}
            fi
        done
        IFS=${OLD_IFS}
    fi
    print -- ${UPPER_SID} - Errors: ${SID_ERRORCOUNT} Warnings: ${SID_WARNINGCOUNT} >> ${OUTPUT_SUMMARY}
}

#######
# Main
#######

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!
while getopts a:A:bcCd:De:fh:Hj:k:K:ms:STt:x o
do      case "$o" in
        a)      MAIL_RECIPIENT=${OPTARG}
                SEND_MAIL="Y";;
        A)      SUMMARY_EMAIL=${TEMP_DIR}/${OPTARG};;
        b)      BRIEF="Y";;
        c)      CRON_MODE="Y";;
        C)      TIMING="N";;
        d)      ONE_DB=${OPTARG};;
        D)      DB_TITLE="N";;
        f)      FEEDBACK="N";;
        h)      MAIL_TITLE=${OPTARG};;
        H)      HEADING_CHANGE="Y";;
        j)      SCRIPT_ID=${OPTARG};;
        k)      INLINE_COLOUR=${OPTARG};;
        K)      ATTACHMENT_COLOUR=${OPTARG};;
        m)      SEND_MAIL="Y";;
        s)      SCRIPT=${OPTARG}
                SCRIPT_STRING='Script';;
        S)      SUMMARY="Y";;
        t)      TYPE_SPECIFIED="Y"
                WHERE_SCRIPT_TYPE1=" AND s.script_type IN ('ALL', '${OPTARG}')"
                WHERE_SCRIPT_TYPE2=" AND a.script_type IN ('ALL', '${OPTARG}')"
                SCRIPT_TYPE=${OPTARG};;
        T)      USE_TNSNAMES="Y";;
        x)      EXTREME="Y";;
        [?])    print -- "${THISSCRIPTNAME}: invalid parameters supplied \n${USAGE}" 
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

#########################
# Create TNS environment 
#########################
if [[ -f ${AMCHECK_DIR}/tnsnames.ora ]]
then
    TNSNAMES=${AMCHECK_DIR}/tnsnames.ora
else
    if [[ ${CRON_MODE} == 'N' ]]
    then
        f_redprint "Expected TNSNAMES file(s) not found. Aborting." >> ${OUTPUT_BUFFER}
    else
        print -- "Expected TNSNAMES file(s) not found. Aborting." >> ${OUTPUT_BUFFER}
    fi
    f_redboldhtml "Expected TNSNAMES file(s) not found. Aborting." >> ${MAIL_BUFFER}
    exit 51
fi

mkdir ${TNS_ADMIN} 2>/dev/null
cp ${TNSNAMES} ${TNS_ADMIN}/.

###########################################################################################################
# We need to get a list of all columns in table am_database in order to validate the positional parameters
###########################################################################################################
sqlplus -s ${AMCHECK_TNS} <<- SQL050 > ${TEMPFILE3}
        set pages 0
        set feedback off
        SELECT column_name FROM all_tab_columns WHERE table_name = 'AM_DATABASE' AND owner = 'AMO' ORDER BY 1;
        exit;
	SQL050
################################################################################################################################
# OK. The remaining positional parameters will be null or a list of column names from am+database with a trailing '+Y' or '_N'.
# We need to validate each of these rather than being clunky and add the text directly to the query. This will help protect
# against SQL injection.
################################################################################################################################

if [[ ${USE_TNSNAMES} == 'Y' ]]
then
    print -- "${THISSCRIPTNAME}: Indicator columns and tnsnames processing are incompatable \n${USAGE}" 
    exit 50
elif [[ ${EXTREME} == 'Y' ]] && [[ ${SEND_MAIL} == 'N' ]]
then
    print -- "${THISSCRIPTNAME}: Extreme indicator only applies to e-mails. Please inspect your parameters: \n${USAGE}" 
    exit 50
elif [[ ! -z ${ONE_DB} ]] && [[ ! -z ${SCRIPT_ID} ]]
then
    print -- "${THISSCRIPTNAME}: WARNING ${ONE_DB} will be used instead of the actual database name for the specified script set." 
elif [[ ! -z ${SCRIPT} ]] && [[ ! -z ${SCRIPT_ID} ]]
then
    print -- "${THISSCRIPTNAME}: Script sets (-j) and script (-s) parameters are mutually exclusive. Please inspect your parameters: \n${USAGE}" 
    exit 50
fi

if [[ `echo ${SUMMARY_EMAIL} | cut -d'+' -f2` == 'print' ]]
then
    SUMMARY_EMAIL_PRINT='Y'
fi
SUMMARY_EMAIL=`echo ${SUMMARY_EMAIL} | cut -d'+' -f1` 

if [[ $# -gt 0 ]]
then
    set $*
    for PAR in "$@"
    do
        INDCOLUMN=${PAR%+*}
        YNIND=${PAR##*+}
        if [[ `grep -cw ${INDCOLUMN} ${TEMPFILE3}` -ne 1 ]]
        then
            print -- "${THISSCRIPTNAME}: Column: ${INDCOLUMN} not found! \n${USAGE}" 
            exit 50
        else
            if [[ ${YNIND} != 'Y' ]] && [[ ${YNIND} != 'N' ]] 
            then
                print -- "${THISSCRIPTNAME}: Please supply parameters in the format of INDICTOR+Y or INDICATOR+N \n${USAGE}" 
                exit 50
            elif [[ ${YNIND} == ${INDCOLUMN} ]] 
            then
                print -- "${THISSCRIPTNAME}: Please supply parameters in the format of INDICTOR+Y or INDICATOR+N \n${USAGE}" 
                exit 50
            fi
            WHERE_ADDITION="${WHERE_ADDITION} AND ${INDCOLUMN} = '${YNIND}'"
        fi
    done
fi
    
if [[ -z ${SCRIPT_ID} ]]
then
	TYPE_COUNT=`sqlplus -s ${AMCHECK_TNS} <<- SQL060
	set pages 0
	set feedback off
	SELECT SUM(rowsfound) FROM (SELECT COUNT(*) AS rowsfound FROM amo.am_scripts   WHERE script_type = '${SCRIPT_TYPE}' AND disabled <> 'Y'
				UNION ALL SELECT COUNT(*)        FROM amo.am_scriptadd WHERE script_type = '${SCRIPT_TYPE}' AND disabled <> 'Y');
	exit;
SQL060
`
    if [[ ${TYPE_COUNT} -eq 0 ]]
    then
        print -- "${THISSCRIPTNAME}: No scripts of type '${SCRIPT_TYPE}' found. \n${USAGE}" 
        exit 50
    fi
fi

if [[ ${HEADING_CHANGE} == 'Y' ]]
then
    MAIL_HEADER=`echo ${MAIL_TITLE} | sed 's/ /_/g'`
fi

rm -f ${MAIL_BUFFER}
rm -f ${MASTER_SCRIPTFILE}
rm -f ${OUTPUT_BUFFER}
rm -f ${OUTPUT_SUMMARY}
rm -f ${SCRIPTFILE}
rm -f ${SUMMARY_BUFFER}
rm -f ${TEMPFILE1}
rm -f ${TEMPFILE6}

touch ${AMCHECK_DIR}/amchecks_sidskipfile
cp ${AMCHECK_DIR}/amchecks_sidskipfile ${SIDSKIPFILE}

# TNSPING location Can only be set once we know ORACLE_HOME..
typeset TNSPING=${ORACLE_HOME}/bin/tnsping

if [[ ! -f ${TNSPING} ]] && [[ ${USE_TNSNAMES} = 'Y' ]]
then
    print -- "Script ${TNSPING} not found. Contact a DBA."  | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER}
    exit 54
fi
print "################################################################ amchecks ########################################################################\n" >> ${OUTPUT_BUFFER}

if [[ ! -z ${SCRIPT} ]]
then
    if [[ ! -f ${AMCHECK_DIR}/${SCRIPT} ]]
    then
        if [[ ${CRON_MODE} == 'N' ]]
        then
            f_redprint "Script ${SCRIPT} not found!" | tee -a ${OUTPUT_BUFFER}
        else
            print -- "Script ${SCRIPT} not found!" >> ${OUTPUT_BUFFER}
        fi
        f_redboldhtml "Script ${SCRIPT} not found!" >> ${MAIL_BUFFER}
        exit 54
    fi
fi

if [[ ${TYPE_SPECIFIED} == 'Y' ]]
then
   MAIL_TITLE="${MAIL_TITLE} - Type: ${SCRIPT_TYPE}"
fi

if [[ ! -z ${SCRIPT} ]]
then
   MAIL_TITLE="${MAIL_TITLE} (${SCRIPT})"
fi

# Format help for the casual reader!

#print "**************************************************************************************" >> ${MAIL_BUFFER}
#print "** To improve readability save this as a 'mht' (MIME HTML) file from within outlook.**" >> ${MAIL_BUFFER} 
#print "**************************************************************************************" >> ${MAIL_BUFFER}
#print "  " >> ${MAIL_BUFFER}

if [[ ! -z ${SCRIPT_ID} ]]
then
    sqlplus -s ${AMCHECK_TNS} <<- SQL070 > ${TEMPFILE6}
        set pages 0
	SET FEEDBACK OFF
	SELECT  d.database_name || '+' || z.script_name || '+' || TRANSLATE(j.title,' ','_') AS database_name
	FROM    amo.am_database d,
		amo.am_server s,
		amo.am_script_set j,
		amo.am_scripts z
	WHERE   j.script_id = z.script_id
	AND     j.database_name = d.database_name
	AND     d.disabled <> 'Y'
	AND     s.disabled <> 'Y' 
	AND     d.server = s.server
	AND     j.set_id = '${SCRIPT_ID}'
	AND     j.disabled <> 'Y'
	ORDER BY j.run_order ASC, z.run_order ASC, d.database_name ASC;
        exit;
	SQL070
        cat ${TEMPFILE6} | sed '/^$/d' | while read SID
        do
          f_run ${SID}
        done
elif [[ ! -z ${ONE_DB} ]]
then
   ################################
   # Only run against one database 
   ################################
   MAIL_TITLE="${MAIL_TITLE} (${ONE_DB})"

   if [[ ${USE_TNSNAMES} == 'Y' ]]
   then
      f_run ${ONE_DB}
   else
        sqlplus -s ${AMCHECK_TNS} <<- SQL98 > ${TEMPFILE6}
	set pages 0
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
		WHERE   d.database_name='${ONE_DB}'
		AND     d.server = s.server)
	exit;
SQL98
      cat ${TEMPFILE6} | sed '/^$/d' | while read SID
      do
        f_run ${SID}
      done
   fi

elif [[ ${USE_TNSNAMES} == 'Y' ]]
then
    if [[ -z ${SCRIPT} ]]
    then
        print -- "Checking databases listed in ${THIS_SERVER}:${TNSNAMES}..."  | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER}
    fi
    grep -v -e '^#' ${TNSNAMES} | grep -i '^[a-zA-Z]' | cut -d '=' -f1  | sort -u > ${TEMPFILE6}
    cat  ${TEMPFILE6} | sort | while read SID
    do
      f_run ${SID}
    done
else  
    if [[ -z ${SCRIPT} ]]
    then
        print -- "Checking databases listed in ${ORACLE_SID}...\n" | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER}
    fi
    sqlplus -s ${AMCHECK_TNS} <<- SQL100 > ${TEMPFILE6}
        set pages 0
	SET FEEDBACK OFF
--	SELECT d.database_name || ' on server ' || s.physical_server_abbrev || CASE WHEN s.cluster_name IS NULL THEN NULL ELSE ' (cluster: ' || s.cluster_name || ')' END AS cluster_name FROM   amo.am_database d, amo.am_server s WHERE  d.server = s.server AND d.disabled <> 'Y' AND s.disabled <> 'Y' ${WHERE_ADDITION} ORDER BY d.run_order ASC, d.database_name ASC;
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
		WHERE   1=1 
		AND     d.disabled <> 'Y'
		AND     s.disabled <> 'Y' ${WHERE_ADDITION} 
		AND     d.server = s.server)
	ORDER BY run_order ASC, database_name ASC;
        exit;
	SQL100
        cat ${TEMPFILE6} | sed '/^$/d' | while read SID
        do
          f_run ${SID}
        done
fi

print "################################################################ amchecks ########################################################################\n" >> ${OUTPUT_BUFFER}

#################################################################################################################
# Utterly horrible cludge to sort out stripping of whitespace from the html output from the 'true space' output
# Should be rewritten to be smarter..                                         
#################################################################################################################
cat ${MAIL_BUFFER} | sed '/--------------- --------- ---------$/s//----------------------------- -------------- --------------- --------- ---------/g' | sed ':a;N;$!ba;s/: \n/: /g' > ${TEMPFILE1} 
cp ${TEMPFILE1} ${MAIL_BUFFER}

#################################
# Construct Summary if necessary
#################################
if [[ ${SUMMARY} == 'Y' ]] 
then
    cat ${MAIL_BUFFER} | egrep 'green|red\>|\<b\>' > ${SUMMARY_BUFFER}
fi

###########################################################
# Tinker with the screen output file before displaying it.
###########################################################
sed ':a;N;$!ba;s/: \n/: /g' < ${OUTPUT_BUFFER} > ${TEMPFILE1}
sed 's/\.\./\  /g' < ${TEMPFILE1} > ${OUTPUT_BUFFER}
sed 's/ \./\  /g' < ${OUTPUT_BUFFER} > ${TEMPFILE1}
cp ${TEMPFILE1} ${OUTPUT_BUFFER}

#ERRORCOUNT=`grep -ic color=red ${MAIL_BUFFER}`
#WARNINGCOUNT=`grep -ic color=green ${MAIL_BUFFER}`
#echo "ERRORS:   ${ERRORCOUNT}" > ${TEMPFILE4}
#echo "WARNINGS: ${WARNINGCOUNT}" >> ${TEMPFILE4}

if [[ -f ${SUMMARY_BUFFER} ]]
then
    cat ${SUMMARY_BUFFER} >> ${TEMPFILE4}
fi
clear screen
cat ${OUTPUT_BUFFER}

if [[ ${SEND_MAIL} == "Y" ]] || [[ ! -z ${SUMMARY_EMAIL} ]]
then
    ######################################################
    # Tinker with the generated html before attaching it.
    ######################################################
    cp ${MAIL_BUFFER} ${TEMPFILE1}
    sed 's/\.\./\&nbsp\&nbsp/g' < ${TEMPFILE1} > ${MAIL_BUFFER}
    sed 's/&nbsp\./\&nbsp\&nbsp/g' < ${MAIL_BUFFER} > ${TEMPFILE1}
    cp ${TEMPFILE1} ${MAIL_BUFFER}

    if [[ ${SCRIPT_STRING} == "Script" ]] 
    then
        if [[ `grep -c 'ERROR' ${MAIL_BUFFER}` -gt 0 ]] ||  [[ `grep -c 'ERROR' ${OUTPUT_BUFFER}` -gt 0 ]]
        then
            MAIL_TITLE="ERROR - ${MAIL_HEADER}"
        fi
    fi

    if [[ ${SEND_MAIL} == "Y" ]] 
    then 
        if [[ ${HEADING_CHANGE} == "Y" ]]
        then
#            f_mail ${MAIL_HEADER} "#702EBF" ${MAIL_RECIPIENT} "${MAIL_BUFFER}(${ATTACHMENT_COLOUR})[monospace]+${TEMPFILE4}(${INLINE_COLOUR})[Lucida]" ${MAIL_TITLE} 
            f_mail ${MAIL_HEADER} "#702EBF" ${MAIL_RECIPIENT} "${MAIL_BUFFER}(${ATTACHMENT_COLOUR})[monospace]+${TEMPFILE4}(${INLINE_COLOUR})[Lucida]" "${MAIL_TITLE}" 
        else
            f_mail ~/amchecks/amchecks.png "#702EBF" "${MAIL_RECIPIENT}" "${MAIL_BUFFER}(${ATTACHMENT_COLOUR})[monospace]+${TEMPFILE4}(${INLINE_COLOUR})[Lucida]" ${MAIL_TITLE}
        fi
    fi

    #################################################################################################################################################
    # Check to see if an additional e-mail (extreme option) is required.
    # This is a horrible clunky cludge of a pattern match. Calling it 'extreme' is mildly outrageous, I know. 
    # It has been hacked to work with the CHECK scripts and will most likely be a complete mess if used in other circumstances!
    #################################################################################################################################################
    if [[ ${EXTREME} == "Y" ]] 
    then
        grep -v '++++++'  ${MAIL_BUFFER} | egrep 'color=red|color=blue|Mountpoint|Theory| \-\-\-\-\-\-\- ' | sed 's/\+//g' |  grep '</font>'  | grep -v 'check)' > ${EXTREME_FILE}
        f_mail Extreme_Summary "#702EBF" ${MAIL_RECIPIENT} "${EXTREME_FILE}(${ATTACHMENT_COLOUR})[monospace]+${TEMPFILE4}(${INLINE_COLOUR})[Lucida]" "Summary ${MAIL_TITLE}"
    fi

    if [[ ! -z ${SUMMARY_EMAIL} ]]
    then
        if [[ ${EXTREME} == "Y" ]] 
        then 
            cat ${EXTREME_FILE} >> ${SUMMARY_EMAIL}
        else
            cat ${MAIL_BUFFER} >> ${SUMMARY_EMAIL}
        fi
        echo "Output appended to ${SUMMARY_EMAIL}"
    fi
fi

if [[ ${SUMMARY_EMAIL_PRINT} == 'Y' ]]
then
    echo "E-mailing ${SUMMARY_EMAIL}"
    echo "Please See attached" > ${TEMPFILE4}
    f_mail ~/amchecks/amchecks.png "#702EBF" "${MAIL_RECIPIENT}" "${SUMMARY_EMAIL}[monospace]+${TEMPFILE4}(${INLINE_COLOUR})[Lucida]" Summary Report 
    rm -f ${SUMMARY_EMAIL}
fi

rm -f ${TEMPFILE4}

exit

