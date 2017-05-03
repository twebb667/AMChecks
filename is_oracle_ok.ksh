#!/bin/ksh
##################################################################################
# Name             : is_oracle_ok
# Author           : Tony Webb
# Created          : 11 Feb 2014
# Type             : Korn shell script
# Version          : 360
# Parameters       : -a (alternative email address)
#		     -h heading
#                    -H hostname
#                    -e (exclusivity) . N.B. Consider setting this one!
#                    -m (mail)
#                    -s (short output)
#                    -S minutes (smart output)
#                    -c ('cron mode')
#                    -k inline background colour (only applicable for e-mails)
#                    -K attachment background colour (only applicable for e-mails)
#	             -l label
#                    -t (use tnsnames)
#                    -T seconds (TNS timeout)
#                    -p (only tnsping)
#                    -P (Server Ping only. Works with -v and -s flags only)
#                    -v (verbose)
#                    indicator+Y or indictor+N columns
#
# Returns          : 0   Success
#                    50  Wrong parameters
#                    51  Missing tnsnames.ora 
#                    54  Missing files
#                    60  Already running 
#
# Notes            : Database listing is taken from a list of databases in
#                    the database specified in .amcheck unless '-t' is used.
#                    Note that the short listing flag is ignored if there
#                    is a database connection error.
#
#                    Specifying the mail flag (-m or -a) will always send an e-mail
#                    Specifying the smart mail flag (-S) will conditionally send an e-mail
#                    The -S flag will override the -a and -m flag but will use the e-mail 
#                    address specified by those flags.
#                    
#                    For smart mail the default should be NOT to send a mail message..
#                    so it is set it to 'M' for maybe!
#
#                    Parameter 'l' is used to label the work/temporary files
#                    so that the script works properly where there are
#                    multiple is_oracle_ok entries in the cron. Keep label names as 
#                    unique as possible.
#
#                    The -P flag is a bit rough and ready. It could be made to work with 
#                    more of the other flags but there's probably not much point!
#                
#                    If a server name and physical server (abbreviated) value are different, 
#                    Use -H with the physical server (abbreviated) value to see ALL databases
#                    on a host; use -H with the server name if you just want to check the server.
#
#      Example calls:
#
#      is_oracle_ok.ksh -c -s -m 
#      is_oracle_ok.ksh -c -s -t -m -p
#      is_oracle_ok.ksh -c -a "fred@flintstones.com"
#      is_oracle_ok.ksh -m -a "wilma@flintstones.com" -h "Threshold Checks" THRESHOLD_IND+Y'
#      is_oracle_ok.ksh -c -s -m -S3 -a "barney@flintstones.com"
#      is_oracle_ok.ksh -c -s -m -S3 -l check1 -a "betty@flintstones.com"
#      is_oracle_ok_ksh -c -e -S15 -s -l test_label -p -a "bambam@flintstones.com" 
#      is_oracle_ok.ksh -Pvs
#
#---------+----------+------------+----------------------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+----------------------------------------------------------
# 010     | 11/02/14 | T. Webb    | Original
# 020     | 15/05/14 | T. Webb    | Changed for running from OEM server
# 030     | 17/06/14 | T. Webb    | Functions moved to separate file
# 040     | 10/07/14 | T. Webb    | Mail option added
# 050     | 14/07/14 | T. Webb    | 'Cron mode' flag added
# 060     | 18/08/14 | T. Webb    | Added notes to sidskip file
# 070     | 01/09/14 | T. Webb    | Changed call to f_mail
# 080     | 13/04/15 | T. Webb    | Added -v option
# 090     | 15/05/15 | T. Webb    | YN indicator parameters added.
#         |          |            | Also added -a and -h options
# 100     | 15/05/15 | T. Webb    | Increased TNS timeout to 5 seconds
# 110     | 22/05/15 | T. Webb    | Added -k and -K options
# 120     | 10/07/15 | T. Webb    | Added -S (smart) mail option
# 130     | 15/07/15 | T. Webb    | Added -l (label) option
# 140     | 04/08/15 | T. Webb    | Changed label processing slightly
# 150     | 05/08/15 | T. Webb    | TNSPING title change
# 160     | 10/08/15 | T. Webb    | SIDSKIP table processing added
# 170     | 02/09/15 | T. Webb    | Added -e (exclusivity) option
# 180     | 17/09/15 | T. Webb    | Added timings (similar code to in other scripts so it 
#         |          |            | should probably be made into a shell function) 
# 190     | 21/12/15 | T. Webb    | Added more sqlnet timeout parameters and checks for
#         |          |            | the job already running.
# 200     | 05/01/16 | T. Webb    | Changed SQL that runs for the checks
# 210     | 05/01/16 | T. Webb    | Sidskip added to output 
# 220     | 07/01/16 | T. Webb    | Fixed a bug due to a while loop affecting the scope of
#         |          |            | a variable (ERROR_IND)
# 230     | 08/01/16 | T. Webb    | More info on title when errors
# 240     | 11/01/16 | T. Webb    | Added TNS_TIMEOUT and more TNS info on output
# 250     | 12/01/16 | T. Webb    | More sqlnet.ora parameters
# 250     | 26/01/16 | T. Webb    | Minor formatting changes
# 270     | 12/04/16 | T. Webb    | Added a couple of 'touch' commands
# 280     | 12/04/16 | T. Webb    | Changes made to label parameter
# 290     | 15/04/16 | T. Webb    | Changes made to verbose option and -A flag added
# 300     | 06/07/16 | T. Webb    | Downgrading of slow connections to WARNING
# 310     | 19/07/16 | T. Webb    | -P option added
# 320     | 20/07/16 | T. Webb    | Minor changes to the -P option and cluster info added
# 330     | 06/09/16 | T. Webb    | physical_server_abbrev added
# 340     | 12/09/16 | T. Webb    | Disable mail with -P flag (add in later?)
# 350     | 03/01/17 | T. Webb    | Find command changes and -f added
# 360     | 03/05/17 | T. Webb    | -H flag added
#############################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -A (alerting enabled) -a mail-address -h title -S nn (Smart mail) -f (force mail) -l label -h heading -H hostname -s (short output) -c (cron mode) -k (inline colour) -K (attachment colour) -t (use tnsnames) -m (mail) -p (only tnsping) -P (server ping only) -v (verbose)"

typeset AGE
typeset -i AGE_MINS=0
typeset ALERT_IND='N'
typeset ATTACHMENT_COLOUR=''
typeset BASENAME
typeset CRON_MODE='N'
typeset -i DIFF_CHECK=0
typeset DIRNAME
typeset -i ELAPSED_SECONDS
typeset -i ERRORCOUNT
typeset ERROR_DB_LIST=' '
typeset ERROR_IND='N'
typeset ERROR_IND_FILE="${TEMP_DIR}/is_oracle_ok_errorind"
typeset ERROR_DB_LIST_FILE="${TEMP_DIR}/is_oracle_ok_error_db_list_file"
typeset ERROR_TEXT=' '
typeset -i ERROR_LENGTH=0
typeset EXCLUSIVITY='N'
typeset FORCE_MAIL='N'
typeset -u HOSTNAME='%'
typeset -u INDCOLUMN
typeset INLINE_COLOUR=''
typeset INLINE_FILE="${TEMP_DIR}/is_oracle_ok_inline"
typeset THIS_SERVER=`hostname -s`
typeset GREP_LABEL=${THISSCRIPTNAME}
typeset LABEL=''
typeset LANG=en_GB
typeset -i LOOPCOUNT
typeset MAIL_BUFFER="${TEMP_DIR}/is_oracle_ok_mail"
#typeset MAIL_RECIPIENT is set in external include file
typeset MAIL_TITLE="Oracle Connectivity Test"
typeset OUTPUT_BUFFER="${TEMP_DIR}/is_oracle_ok_output"
typeset -i PAD_LENGTH
typeset PING='/bin/ping -c1 -t2'
typeset PING_ONLY='N'
typeset PREV_MAIL_BUFFER="${TEMP_DIR}/prev_is_oracle_ok_mail"
typeset -i RUNCOUNT=0
typeset SECONDS_STRING="seconds"
typeset SEND_MAIL='N'    
typeset SERVERPING_ONLY='N'
typeset SHORT_LISTING='N'
typeset SID
typeset -u SID_ERRORS='N'
typeset SID_SKIP_FILE="${TEMP_DIR}/is_oracle_ok_sidskipfile"
typeset DBSID_SKIP_FILE="${TEMP_DIR}/is_oracle_ok_dbsidskipfile"
typeset SIDSKIP_NOTES
typeset -i SIDSKIP_TABLE_COUNT
typeset -i SID_LENGTH
typeset SMART_MAIL='N'
typeset SQLCHECK
typeset START_DATE=`date +%d-%m-%y:%H.%M.%S`
typeset START_DATE_PRETTY=`date "+%a %d %b %Y at %I:%M:%S %p"`
typeset START_DAY=${START_DATE%%:*}
typeset START_SEC=`echo ${START_DATE##*:} | awk -F. '{ print ($1 *3600 ) + ( $2 * 60 ) + $3 }'`
typeset STATUS_FILE="${TEMP_DIR}/is_oracle_ok_status"
typeset STOP_DATE
typeset STOP_DAY
typeset STOP_SEC
typeset TARGET
typeset TEMP_FILE1="${TEMP_DIR}/is_oracle_ok_tempfile1"
typeset TEMP_FILE2="${TEMP_DIR}/is_oracle_ok_check.lst"
typeset TEMP_FILE3="${TEMP_DIR}/is_oracle_ok_dblist.lst"
typeset TEMP_FILE4="${TEMP_DIR}/is_oracle_ok_cols.lst"
typeset TEMP_FILE5="${TEMP_DIR}/is_oracle_ok_p2.lst"
typeset TNSNAMES
typeset TNS_ADMIN=${AMCHECK_DIR}
export TNS_ADMIN
typeset -i TNS_STATUS=0
typeset TNS_STATUS_FILE="${TEMP_DIR}/is_oracle_ok_tnsstatusfile"
typeset TNS_STATUS_TEXT
typeset -i TNS_TIMEOUT=10
typeset -i TNS_TIME_TAKEN
typeset USE_TNSNAMES='N'    
typeset VERBOSE='N'    
typeset WHERE_ADDITION=' '
typeset -u YNIND

#############
# Functions
#############

# Read standard amchecks functions
#. ${AMCHECK_DIR}/functions.ksh

#####################
# Database Alerting
#####################

function f_alert    
{                  
    ####################################################################
    # N.B. Parameters will be dbname (tns entry) followed by error text
    # Currently only an e-mail is generated when an alert is triggered.
    ####################################################################
    typeset -i ALERTCOUNT=0
    typeset SID=${1}
    shift 1
    ERROR=$*
    print "Database ${SID} errors detected!" > ${TEMP_FILE5}

	ALERTCOUNT=`sqlplus -s ${AMCHECK_TNS} <<- ALERT10
		set pages 0
		set feedback off
		SELECT count(*) from amo.am_alert WHERE database_name = '${SID}';
		exit;
	ALERT10`

    if [[ ${ALERTCOUNT} -gt 0 ]]
    then
        print "Alert for ${SID} already processed" 
    else
        print " " >> ${TEMP_FILE5}
        f_redboldhtml "${ERROR}" >> ${TEMP_FILE5}
        f_mail ~/amchecks/is_oracle_ok.png "#702EBF" ${MAIL_RECIPIENT} ${TEMP_FILE5} "URGENT P2 Alert generated for ${SID}"

        ################################################
        # The error text may cause the insert to fail..
        ################################################
        print "Alert for ${SID} being created..."
   
	sqlplus -s ${OWNER_CONNECT} <<- ALERT20
		INSERT INTO amo.am_alert (database_name, notes) VALUES ('${SID}', '${ERROR}');
		exit;
	ALERT20
    fi

}

###########################
# Database Connection test
###########################

function f_connect    
{                  
    ########################################################
    # N.B. Parameter will either be dbname or dbname server
    ########################################################
    set $*
    typeset SID=${1}
    shift 1
    typeset SERVER="${*}"
   
    typeset -u UPPER_SID=${SID}
  
    if [[ ${VERBOSE} == "Y" ]] 
    then
        if [[ ${USE_TNSNAMES} == "Y" ]]
        then
            typeset HOST=`f_gethost ${SID} ${TNSNAMES}`
        else
            typeset HOST=${SERVER}
        fi

        if [[ -z ${HOST} ]]
        then
            HOST='unknown'
        fi
        typeset -L60 PRINT_SID="Processing ${UPPER_SID} (on ${HOST})  "
    else
        typeset -L30 PRINT_SID="Processing ${UPPER_SID}               "
    fi

    print -n "\t${PRINT_SID}"  | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER} 
    
    SID_LENGTH=`echo ${UPPER_SID} | wc -c`
    PAD_LENGTH=`expr "20" - "${SID_LENGTH}"`
    LOOPCOUNT=1
    while [[ ${LOOPCOUNT} -le ${PAD_LENGTH} ]]
    do
        UPPER_SID="${UPPER_SID}."
        let LOOPCOUNT=LOOPCOUNT+1
    done

    touch ${INLINE_FILE}
    print -n "${PRINT_SID} "  >> ${INLINE_FILE} 
    if [[ `grep -icw ^${SID} ${SID_SKIP_FILE}` -gt 0 ]] 
    then 
        SIDSKIP_NOTES=`grep -iw ^${SID} ${SID_SKIP_FILE} | cut -d' ' -f2-`
        if [[ -z ${SIDSKIP_NOTES} ]]
        then
            SIDSKIP_NOTES=''
        else
            SIDSKIP_NOTES="(${SIDSKIP_NOTES})"
        fi
        print " Intentionally skipped ${SIDSKIP_NOTES}"  | tee -a ${INLINE_FILE}
        if [[ ${CRON_MODE} == "N" ]]
        then
            f_yellowprint " Intentionally skipped ${SIDSKIP_NOTES}" >> ${OUTPUT_BUFFER}
        else
            print " Intentionally skipped ${SIDSKIP_NOTES}" >> ${OUTPUT_BUFFER}
        fi
        f_blueboldhtml " Intentionally skipped ${SIDSKIP_NOTES}" >> ${MAIL_BUFFER}
    else
        ${TNSPING} ${SID} 1>${TNS_STATUS_FILE} 2>&1
        TNS_STATUS=$?
        ##################################################
        # Keep a separate tnsping.trc for each connection
        ##################################################
        cp ${TNS_ADMIN}/tnsping.trc ${TNS_ADMIN}/traces/${SID}_tnsping.trc
        if [[ ${TNS_STATUS} -eq 0 ]]
        then
            TNS_STATUS_TEXT=`tail -1 ${TNS_STATUS_FILE} | cut -d' ' -f2-`
            TNS_TIME_TAKEN=`echo ${TNS_STATUS_TEXT} | cut -d'(' -f2- | cut -d' ' -f1`
            if (( TNS_TIME_TAKEN > TNS_TIMEOUT*1000 ))
            then
                TNS_STATUS=501
                if [[ `grep -c "ERROR" ${STATUS_FILE}` -lt 1 ]]
		then
                    echo "WARNING" > ${STATUS_FILE}
                    MAIL_TITLE="WARNING - Oracle Connectivity"
                fi
            fi
        else
            echo "ERROR" > ${STATUS_FILE}
            MAIL_TITLE="ERROR - Oracle Connectivity"
            cp ${TNS_ADMIN}/traces/${SID}_tnsping.trc ${TNS_ADMIN}/traces/${SID}_tnsping_last_error.trc
            TNS_STATUS_TEXT=`tail -1 ${TNS_STATUS_FILE}`
        fi
        if [[ ${TNS_STATUS} -ne 0 ]]
        then
            ERROR_DB_LIST="${ERROR_DB_LIST} ${SID} "
            print " ** Unable to tnsping ${SID}! (${TNS_STATUS_TEXT}) **"  | tee -a ${INLINE_FILE}
            if [[ ${CRON_MODE} == "N" ]]
            then
                f_redprint " ** Unable to tnsping ${SID}! (${TNS_STATUS_TEXT}) **" >> ${OUTPUT_BUFFER}
            else
                print " ** Unable to tnsping ${SID}! (${TNS_STATUS_TEXT}) **" >> ${OUTPUT_BUFFER}
            fi
            f_redboldhtml " ** Unable to tnsping ${SID}! (${TNS_STATUS_TEXT}) **" >> ${MAIL_BUFFER}
            if [[ ${SEND_MAIL} == "M" ]]
            then
                SEND_MAIL='Y'
            fi
            ERROR_IND='Y'
        else
            if [[ ${PING_ONLY} == "N" ]]
            then
		SQLCHECK=`sqlplus -s -L ${CONNECT}\@${SID} <<- SQL05
		set pages 0
		set feedback off
		SELECT count(*) from user_users;
		exit;
		SQL05`
                ERRORCOUNT=`echo ${SQLCHECK} | grep -c "ORA-"`
                ERROR_TEXT=`echo ${SQLCHECK} | grep "ORA-"`
	    else 
                ERRORCOUNT=0
            fi
            if [[ ${ERRORCOUNT} -gt 0 ]]
            then
                print " ** Failed to connect (sqlplus) to Oracle (TNSPING Status: ${TNS_STATUS_TEXT}) **"  | tee -a ${INLINE_FILE}
                if [[ ${CRON_MODE} == "N" ]]
                then
                    f_redprint " ** Failed to connect (sqlplus) to Oracle (TNSPING Status: ${TNS_STATUS_TEXT}) **" >> ${OUTPUT_BUFFER}
                else
                    print " ** Failed to connect (sqlplus) to Oracle (TNSPING Status: ${TNS_STATUS_TEXT}) **" >> ${OUTPUT_BUFFER}
                fi
                f_redboldhtml " ** Failed to connect (sqlplus) to Oracle (TNSPING Status: ${TNS_STATUS_TEXT}) **" >> ${MAIL_BUFFER}

                if [[ ${SEND_MAIL} == "M" ]]
                then
                    SEND_MAIL='Y'
                fi

                if [[ ! -z ${ERROR_TEXT} ]]
                then
                    print "** ${SID} - ${ERROR_TEXT} **" | tee -a ${OUTPUT_BUFFER} 
                    f_redboldhtml "** ${SID} - ${ERROR_TEXT} **" >> ${MAIL_BUFFER}
                    if [[ ${ALERT_IND} == "Y" ]]
                    then
                        f_alert ${SID} ${ERROR_TEXT}
                    fi
                fi
                ERROR_IND='Y'
                MAIL_TITLE="ERROR - Oracle Connectivity"
                ERROR_DB_LIST="${ERROR_DB_LIST} ${SID} "
                echo "ERROR" > ${STATUS_FILE}
            else
                print " Looks OK ${TNS_STATUS_TEXT}" >> ${INLINE_FILE}
                if [[ ${CRON_MODE} == "N" ]]
                then
                    f_greenprint " Looks OK ${TNS_STATUS_TEXT}" >> ${OUTPUT_BUFFER}
                else
                    print " Looks OK ${TNS_STATUS_TEXT}" >> ${OUTPUT_BUFFER}
                fi
                f_greenboldhtml " Looks OK ${TNS_STATUS_TEXT}" >> ${MAIL_BUFFER}
            fi
        fi
    fi
}

function f_ping    
{                  
    typeset SERVER=${1}
    if [[ ${VERBOSE} == "Y" ]]
    then
        print -n "Pinging ${SERVER}... "
    elif [[ ${SHORT_LISTING} != "Y" ]]
    then 
        print -n "."
    fi
    ${PING} ${SERVER} >/dev/null 2>&1
    if [[ $? -eq 0 ]]
    then
        if [[ ${VERBOSE} == "Y" ]]
        then
            print "OK"
        fi
    else
        if [[ ${SHORT_LISTING} != "Y" ]]
        then 
            print 
        fi
        print "** ERROR pinging server ${SERVER} **"
    fi

}

#######
# Main
#######

# Include additional info for the morning checks
. ${AMCHECK_DIR}/.amcheck
. ${AMCHECK_DIR}/functions.ksh

#############################################################
# Get optional parameters. See usage variable for parameters
#############################################################
# 'h' (help) not mentioned so it will display usage and error!
while getopts Aa:cefh:H:k:K:l:mpPsS:tT:v o
do      case "$o" in
        A)      ALERT_IND='Y';;
	a)      MAIL_RECIPIENT=${OPTARG}
                SEND_MAIL='Y';;
        c)      CRON_MODE='Y';;
        e)      EXCLUSIVITY='Y';;
        f)      FORCE_MAIL='Y';;
	h)      MAIL_TITLE=${OPTARG};;
	H)      HOSTNAME=${OPTARG};;
	k)      INLINE_COLOUR=${OPTARG};;
	K)      ATTACHMENT_COLOUR=${OPTARG};;
	l)      LABEL=${OPTARG};;
        m)      SEND_MAIL='Y';;
        p)      PING_ONLY='Y';;
        P)      SERVERPING_ONLY='Y';;
        s)      SHORT_LISTING='Y';;
        S)      SMART_MAIL='Y'
                SEND_MAIL='M'
                AGE_MINS=${OPTARG};;
        t)      USE_TNSNAMES='Y';;
	T)      TNS_TIMEOUT=${OPTARG};;
        v)      VERBOSE='Y';;
        [?])    print "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}" 
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ ${AGE_MINS} -lt 1 ]] && [[ ${SMART_MAIL} == "Y" ]]
then
    print "${THISSCRIPTNAME}: age parameter (-S) must be a positive integer - ${USAGE}"  
    exit 50
elif [[ ${SERVERPING_ONLY} == "Y" ]] && [[ ${SEND_MAIL} != "N" ]]
then
    print "${THISSCRIPTNAME}: -P parameter is not currently coded to send e-mail. Continuing.."  
    SEND_MAIL='N'
    SMART_MAIL='N'
fi

if [[ ! -z ${LABEL} ]]
then
    DBSID_SKIP_FILE="${DBSID_SKIP_FILE}_${LABEL}"
    ERROR_IND_FILE="${ERROR_IND_FILE}_${LABEL}"
    ERROR_DB_LIST_FILE="${ERROR_DB_LIST_FILE}_${LABEL}"
    GREP_LABEL="${LABEL}"
    INLINE_FILE="${INLINE_FILE}_${LABEL}"
    MAIL_BUFFER="${MAIL_BUFFER}_${LABEL}"
    OUTPUT_BUFFER="${OUTPUT_BUFFER}_${LABEL}"
    PREV_MAIL_BUFFER="${PREV_MAIL_BUFFER}_${LABEL}"
    SID_SKIP_FILE="${SID_SKIP_FILE}_${LABEL}"
    STATUS_FILE="${STATUS_FILE}_${LABEL}"
    TEMP_FILE1="${TEMP_FILE1}_${LABEL}"
    TEMP_FILE2="${TEMP_FILE2}_${LABEL}"
    TEMP_FILE3="${TEMP_FILE3}_${LABEL}"
    TEMP_FILE4="${TEMP_FILE4}_${LABEL}"
    TNS_STATUS_FILE="${TNS_STATUS_FILE}_${LABEL}"
fi

rm -f ${TEMP_FILE5}
echo "${ERROR_DB_LIST}" > ${ERROR_DB_LIST_FILE}

if [[ ${EXCLUSIVITY} == 'Y' ]]
then
    #############################################################
    # Check to see if program is already running. Abort if it is.
    #############################################################
    RUNCOUNT=`ps aux | grep ${THISSCRIPTNAME} | grep -v grep | grep -c ${GREP_LABEL}`
    if [[ ${RUNCOUNT} -gt 2 ]]
    then
        print "${THISSCRIPTNAME}: Already running. Aborting..."  
        exit 60
    fi
fi

if [[ ${USE_TNSNAMES} == "Y" ]]
then
    PREV_MAIL_BUFFER="${PREV_MAIL_BUFFER}_tnsnames"
fi
echo "SUCCESS" > ${STATUS_FILE}

###########################################################################################################
# We need to get a list of all columns in table am_database in order to validate the positional parameters
###########################################################################################################
sqlplus -s ${AMCHECK_TNS} <<- SQL010 > ${TEMP_FILE4}
	set pages 0
	set feedback off
	SELECT column_name FROM all_tab_columns WHERE table_name = 'AM_DATABASE' AND owner = 'AMO' ORDER BY 1;
	exit;
	SQL010
################################################################################################################################
# OK. The remaining positional parameters will be null or a list of column names from am+database with a trailing '+Y' or '_N'.
# We need to validate each of these rather than being clunky and add the text directly to the query. This will help protect
# against SQL injection.
################################################################################################################################

if [[ $# -gt 0 ]]
then
    if [[ ${USE_TNSNAMES} == 'Y' ]]
    then
        print "${THISSCRIPTNAME}: Indicator columns and tnsnames processing are incompatable \n${USAGE}"
        exit 50
        if [[ ${HOSTNAME} != '%' ]]
        then
            print "${THISSCRIPTNAME}: Hosthame (-H) parameter is not compatable with tnsnames processing (at present) \n${USAGE}"
            exit 50
        fi
    fi
    set $*
    for PAR in "$@"
    do
        INDCOLUMN=${PAR%+*}
        YNIND=${PAR##*+}
        if [[ `grep -cw ${INDCOLUMN} ${TEMP_FILE4}` -ne 1 ]]
        then
            print "${THISSCRIPTNAME}: Column: ${INDCOLUMN} not found! \n${USAGE}"
            exit 50
        else
            if [[ ${YNIND} != "Y" ]] && [[ ${YNIND} != "N" ]]
            then
                print "${THISSCRIPTNAME}: Please supply parameters in the format of INDICTOR+Y or INDICATOR+N \n${USAGE}"
                exit 50
            elif [[ ${YNIND} == ${INDCOLUMN} ]]
            then
                print "${THISSCRIPTNAME}: Please supply parameters in the format of INDICTOR+Y or INDICATOR+N \n${USAGE}"
                exit 50
            fi
            WHERE_ADDITION="${WHERE_ADDITION} AND ${INDCOLUMN} = '${YNIND}'"
        fi
    done
fi

# TNSPING location Can only be set once we know ORACLE_HOME..
typeset TNSPING=${ORACLE_HOME}/bin/tnsping

rm -f ${MAIL_BUFFER}
rm -f ${OUTPUT_BUFFER}
rm -f ${INLINE_FILE}

print "\n" >> ${OUTPUT_BUFFER} 
print "################################### is_oracle_ok ########################################\n" | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER} 
if [[ ! -f ${TNSPING} ]] && [[ ${USE_TNSNAMES} == "Y" ]]
then
    print "Script ${TNSPING} not found. Contact a DBA." >> ${OUTPUT_BUFFER}
    exit 54
fi

#################################
# Create environment for tnsping
#################################
if [[ -f ${AMCHECK_DIR}/tnsnames.ora ]]
then
    TNSNAMES=${AMCHECK_DIR}/tnsnames.ora
else
    if [[ ${CRON_MODE} == "N" ]]
    then
        f_redprint "Expected TNSNAMES file(s) not found. Aborting." >> ${OUTPUT_BUFFER}
    else
        print "Expected TNSNAMES file(s) not found. Aborting." >> ${OUTPUT_BUFFER}
    fi
    exit 51
fi

#############################################################################
# Note that the sqlnet.ora parameters seem to have little effect on TNSPING
# but will affect sqlplus connections.
# Also note that sqlnet.ora is currently shared in AMChecks so use caution
# if changing settings.
#############################################################################

mkdir -p ${TEMP_DIR} 2>/dev/null
mkdir -p ${TNS_ADMIN}/traces 2>/dev/null

#sqlnet.recv_timeout=${TNS_TIMEOUT} 
cat > ${TNS_ADMIN}/sqlnet.ora <<- SQLNET01

tcp.connect_timeout=${TNS_TIMEOUT} 
names.ldap_conn_timeout=${TNS_TIMEOUT} 
sqlnet.inbound_connect_timeout=${TNS_TIMEOUT} 
sqlnet.outbound_connect_timeout=${TNS_TIMEOUT} 
sqlnet.radius_authentication_timeout=${TNS_TIMEOUT} 
# Don't set the one below if you have a local database!
#sqlnet.authentication_services=(NONE)
sqlnet.recv_timeout=60
sqlnet.send_timeout=${TNS_TIMEOUT} 
#trace_level_client=16 
#trace_file_client=cli 
#trace_directory_client=${TNS_ADMIN} 
#trace_unique_clent=on 
#trace_filelen_client=100 
#trace_fileno_client=2 
log_file_client=cli 
log_directory_client=${TNS_ADMIN} 
tnsping.trace_directory=${TNS_ADMIN} 
tnsping.trace_level=admin 

SQLNET01

touch ${AMCHECK_DIR}/is_oracle_ok_sidskipfile
cp ${AMCHECK_DIR}/is_oracle_ok_sidskipfile ${SID_SKIP_FILE}

##################################################################################
# Either parse tnsnames.ora or read from database to get list of target databases
##################################################################################
if [[ ${SERVERPING_ONLY} == "Y" ]]
then
    echo
    if [[ ${USE_TNSNAMES} == "Y" ]]
    then
        awk '{print toupper($0)}' tnsnames.ora | sed 's/HOST[ ]*=/!/' | awk -F! '{ print $2 }' | awk -F\) '{ print $1 }' | sed 's/ //' | sort -u | while read HOST_STRING
        do
            f_ping ${HOST_STRING}
        done
    else
    	sqlplus -s ${AMCHECK_TNS} <<- SQL090 > ${TEMP_FILE3}
    	set pages 0
    	set feedback off
    	SELECT distinct physical_server FROM amo.am_server WHERE disabled <> 'Y' AND (UPPER(server) LIKE '${HOSTNAME}' OR UPPER(physical_server_abbrev) LIKE '${HOSTNAME}') AND ping_disabled <> 'Y' ORDER BY 1;
    	exit;
SQL090
        cat ${TEMP_FILE3} | sed '/^$/d' | while read HOST_STRING
	do
            f_ping ${HOST_STRING}
	done
    fi
    echo
elif [[ ${USE_TNSNAMES} == "Y" ]]
then
    print "Checking databases listed in ${THIS_SERVER}:${TNSNAMES}...\n" | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER} 
    grep -v -e '^#' ${TNSNAMES} | grep -i '^[a-zA-Z]' | cut -d '=' -f1  | sort -u > ${TEMP_FILE1}
    cat  ${TEMP_FILE1} |
    sort | while read SID
    do
      f_connect ${SID}
    done
else
    print "Checking databases listed in ${ORACLE_SID}...\n" | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER}

    ##########################################################################################
    # Grab a list of databases that need skipping. Use the database table not the SID_SKIP_FILE
    ##########################################################################################
    SIDSKIP_TABLE_COUNT=`sqlplus -s ${AMCHECK_TNS} <<- 090
	set pages 0 
	set feedback off 
	SELECT count(*) FROM all_tables WHERE owner = 'AMO' AND table_name = 'AM_SIDSKIP';
	exit;
090
`
    if [[ ${SIDSKIP_TABLE_COUNT} -gt 0 ]]
    then
    	sqlplus -s ${AMCHECK_TNS} <<- SQL095 > ${DBSID_SKIP_FILE}
	set pages 0
	set feedback off
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
    	exit;
SQL095
    else
    	sqlplus -s ${AMCHECK_TNS} <<- SQL096 > ${DBSID_SKIP_FILE}
	set pages 0
	set feedback off
	SELECT database_name || ' (skipped as database marked as disabled)'
	FROM  amo.am_database
	WHERE disabled = 'Y';
    	exit;
SQL096
    fi
    SID_SKIP_FILE="${DBSID_SKIP_FILE}"

    sqlplus -s ${AMCHECK_TNS} <<- SQL100 > ${TEMP_FILE3}
    set pages 0
    set feedback off
	SELECT d.database_name || ' ' || 
		CASE WHEN s.server = s.physical_server_abbrev THEN s.server ELSE s.server || 
		' (' || s.physical_server_abbrev || ')' END || 
		CASE WHEN s.cluster_name IS NULL THEN NULL ELSE ' [' || s.cluster_name || '] ' END 
	FROM    amo.am_database d, 
		amo.am_server s 
	WHERE   d.server = s.server 
	AND     (UPPER(s.server) LIKE '${HOSTNAME}' OR UPPER(s.physical_server_abbrev) LIKE '${HOSTNAME}')
	AND     d.disabled <> 'Y' ${WHERE_ADDITION} ORDER BY 1;
    exit;
SQL100
    ##############################################################################################################
    # Note that any variable manipulation in f_connect is effectively lost as the while loop creates a new shell
    # so we need to write output to a file. It's a bit pants but works.
    ##############################################################################################################
    echo "${ERROR_IND}" > ${ERROR_IND_FILE}
    cat ${TEMP_FILE3} | sed '/^$/d' | while read SID
    do
      echo "Trying to connect to ${SID}"
      f_connect "${SID}"
      if [[ ${ERROR_IND} == "Y" ]]
      then
          echo "${ERROR_IND}" > ${ERROR_IND_FILE}
          echo "${ERROR_DB_LIST}" > ${ERROR_DB_LIST_FILE}
      fi
    done
    ERROR_IND=`cat ${ERROR_IND_FILE}`
    ERROR_DB_LIST=`cat ${ERROR_DB_LIST_FILE}`
fi

STOP_DATE=`date +%d-%m-%y:%H.%M.%S`
STOP_DAY=${STOP_DATE%%:*}
STOP_SEC=`echo ${STOP_DATE##*:} | awk -F. '{ print ($1 *3600 ) + ( $2 * 60 ) + $3 }'`

if [[ ${STOP_DAY} != ${START_DAY} ]]
then
    ############################################################################################
    # assumes 1 day different max i.e. job ran over midnight but took less than a day in total!
    ############################################################################################
    let "ELAPSED_SECONDS = ${STOP_SEC} - ${START_SEC} + 86400"
else
    let "ELAPSED_SECONDS = ${STOP_SEC} - ${START_SEC}"
fi

if [[ ${ELAPSED_SECONDS} -eq 1 ]]
then
    SECONDS_STRING="second"
fi

print "\nConnectivity checks ran at ${START_DATE_PRETTY} and completed in ${ELAPSED_SECONDS} ${SECONDS_STRING} (Timeout=${TNS_TIMEOUT} seconds) " | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER}

########################################################
# Add sidskip info to attachment for anybody interested
########################################################
if [[ ${USE_TNSNAMES} == 'Y' ]] && [[ -f ${SID_SKIP_FILE} ]]
then
    print "\nThe following databases were intentionally skipped:\n" >> ${MAIL_BUFFER}
    cat ${SID_SKIP_FILE} >> ${MAIL_BUFFER} 
elif [[ ${USE_TNSNAMES} == 'N' ]] && [[ -f ${DBSID_SKIP_FILE} ]]
then
    print "\nThe following databases were intentionally skipped:\n" >> ${MAIL_BUFFER}
    cat ${DBSID_SKIP_FILE} >> ${MAIL_BUFFER} 
fi

print "\n################################### is_oracle_ok ########################################" | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER} 
print | tee -a ${MAIL_BUFFER} >> ${OUTPUT_BUFFER} 

if [[ ${SMART_MAIL} == "Y" ]] 
then
    #############################################################
    # Next bit handles whether or not to actually send an e-mail
    #############################################################
    if [[ ! -f ${PREV_MAIL_BUFFER} ]]
    then
        touch ${PREV_MAIL_BUFFER}
    fi
#    DIFF_CHECK=`diff <( grep -v completed ${MAIL_BUFFER} ) <( grep -v completed ${PREV_MAIL_BUFFER} ) | wc -c`

    rm -f ${MAIL_BUFFER}_1
    touch ${MAIL_BUFFER}_1
    grep -v completed ${MAIL_BUFFER} | while read LINE
    do
        echo ${LINE} | cut -d'(' -f1 >> ${MAIL_BUFFER}_1
    done
    
    rm -f ${PREV_MAIL_BUFFER}_1
    touch ${PREV_MAIL_BUFFER}_1

    grep -v completed ${PREV_MAIL_BUFFER} | while read LINE
    do
        echo ${LINE} | cut -d'(' -f1 >> ${PREV_MAIL_BUFFER}_1
    done
    DIFF_CHECK=`diff ${MAIL_BUFFER}_1 ${PREV_MAIL_BUFFER}_1 | wc -c`

    ########################################################################
    # Differences could be written to a file
    # diff ${MAIL_BUFFER}_1 ${PREV_MAIL_BUFFER}_1 > /tmp/amchecks/difflist
    # echo "There is a difference! Check /tmp/amchecks/difflist"
    ########################################################################
#    `find ${PREV_MAIL_BUFFER} -mmin +${AGE_MINS}` > /tmp/tony_debug
    DIRNAME=`dirname ${PREV_MAIL_BUFFER}`
    BASENAME=`basename ${PREV_MAIL_BUFFER}`
#    `find ${DIRNAME} -name ${BASENAME} -mmin +${AGE_MINS}` > /tmp/tony_debug
#    echo "find command is find ${DIRNAME} -name ${BASENAME} -mmin +${AGE_MINS} > /tmp/tony_debug"

    if [[ ${DIFF_CHECK} -gt 0 ]] 
    then
        SHORT_LISTING='N'
        SEND_MAIL='Y'
        cp ${MAIL_BUFFER} ${PREV_MAIL_BUFFER}
    else
        #############################################################################
        # no change since last check so don't e-mail if asking for a short output
        # ..unless there is an error and it's still there after ${AGE_MINS) minutes
        #############################################################################

        AGE=`find ${PREV_MAIL_BUFFER} -mmin +${AGE_MINS}`
        if [[ ! -z ${AGE} ]] && [[ ${ERROR_IND} == "Y" ]]
        then
            SEND_MAIL='Y'
#            echo "debug. Age (filename) is ${AGE} and ERROR_IND is ${ERROR_IND}" > /tmp/tony_debug1
#            ls -l ${AGE} >> /tmp/tony_debug1
        else
            SEND_MAIL='N'
#           echo "Debug No difference from the previous check. Age is (filename) ${AGE}; AGE Mins is ${AGE_MINS}; ERROR_IND is ${ERROR_IND}; SEND_MAIL is ${SEND_MAIL}" > /tmp/tony_debug2
#            ls -l ${AGE} >> /tmp/tony_debug2
        fi
    fi
fi

if [[ ${SHORT_LISTING} == "N" ]] || [[ ${ERROR_IND} == "Y" ]]
then
    cat ${OUTPUT_BUFFER}
fi
    
if [[ ${PING_ONLY} == "Y" ]]
then
    MAIL_TITLE="${MAIL_TITLE} - Tnsping Only "
fi
#if [[ ! -z ${LABEL} ]]
#then
#    MAIL_TITLE="${MAIL_TITLE} (${LABEL})"
#fi

if [[ `grep -c "ERROR" ${STATUS_FILE}` -gt 0 ]]
then
    if [[ `echo ${MAIL_TITLE} | wc -c` -lt 71 ]]
    then
        MAIL_TITLE="${MAIL_TITLE} (${ERROR_DB_LIST})"
    fi
fi

if [[ ${SEND_MAIL} == "Y" ]] || [[ ${FORCE_MAIL} == "Y" ]]
then
#        f_mail Database_connectivity green ${MAIL_RECIPIENT} ${MAIL_BUFFER} ${MAIL_TITLE}
#        f_mail ~/amchecks/is_oracle_ok.png "#702EBF" ${MAIL_RECIPIENT} ${MAIL_BUFFER} ${MAIL_TITLE}

        f_mail ~/amchecks/is_oracle_ok.png "#702EBF" ${MAIL_RECIPIENT} ${MAIL_BUFFER}+${INLINE_FILE} ${MAIL_TITLE}

#        f_mail ~/amchecks/is_oracle_ok.png "#702EBF" ${MAIL_RECIPIENT} ${MAIL_BUFFER}(ivory)+${INLINE_FILE} ${MAIL_TITLE}
#        f_mail ~/amchecks/is_oracle_ok.gif "#702EBF" ${MAIL_RECIPIENT} ${MAIL_BUFFER}(${ATTACHMENT_COLOUR})+${MAIL_BUFFER}(${INLINE_COLOUR}) ${MAIL_TITLE}
#        f_mail ~/amchecks/is_oracle_ok.gif "#702EBF" ${MAIL_RECIPIENT} ${MAIL_BUFFER}(${ATTACHMENT_COLOUR})+${MAIL_BUFFER}(${INLINE_COLOUR}[Courier]) ${MAIL_TITLE}
#        f_mail ~/amchecks/is_oracle_ok.gif "#702EBF" ${MAIL_RECIPIENT} "null"+${INLINE_FILE}(${INLINE_COLOUR}[Courier]) ${MAIL_TITLE}
#        f_mail ~/amchecks/is_oracle_ok.gif "#702EBF" ${MAIL_RECIPIENT} "null"+${MAIL_BUFFER}(${INLINE_COLOUR})[Courier] ${MAIL_TITLE}

#    f_mail ~/amchecks/is_oracle_ok.gif "#702EBF" ${MAIL_RECIPIENT} "null(green)[Arial]"+${MAIL_BUFFER}(${INLINE_COLOUR})[Courier] ${MAIL_TITLE}

         touch ${PREV_MAIL_BUFFER} 
fi

rm -f ${TEMP_FILE4}

exit 0

