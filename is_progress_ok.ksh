#!/bin/ksh
##################################################################################
# Name             : is_progress_ok
# Author           : Tony Webb
# Created          : 19 Jan 2017
# Type             : Korn shell script
# Version          : 050
# Parameters       : -m (mail)
#                    -a alternative e-mail
#                    -M (always send mail)
#                    -p (ping check only)
#                    -r reminder_mins
#                    -S (smart mail)
#                    -v (verbose)
#                    YNIndicators e.g. PRODUCTION_IND+Y (must be last parameters)
#
# Returns          : 0   Success
#                    50  Wrong parameters
#
# Notes            : 
#
#---------+----------+------------+----------------------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+----------------------------------------------------------
# 010     | 19/01/17 | T. Webb    | Original
# 020     | 01/02/17 | T. Webb    | Added -v parameter
# 030     | 03/02/17 | T. Webb    | Increased PING time threshold (2 to 10)
# 040     | 21/02/17 | T. Webb    | Added in 'ind column params and run_order column/logic
# 050     | 10/04/17 | T. Webb    | Better error handling (e.g. account locked)
#############################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -M (always send mail) -m (mail) -a alternative_address -S (smart mail) -r reminder_mins YNIndicators"

typeset ERRORFILE="${TEMP_DIR}/progerror"
typeset ERROR_IND='N'
typeset -u INDCOLUMN
typeset LAST_EMAIL_BUFFER="is_progress_ok_last_output" 
typeset MAIL_BUFFER="${TEMP_DIR}/is_progress_ok_mail"
#typeset MAIL_RECIPIENT is set in external include file
typeset MAIL_TITLE="Progress_Connectivity_Test"
typeset OUTPUT_BUFFER="${TEMP_DIR}/is_progress_ok_output"
typeset PAR
typeset PING='/bin/ping -c1 -t10'
typeset -i REMINDER_TIME=0
typeset SEND_MAIL='N'
typeset SMART_MAIL='N'
typeset SPACE
typeset TEMP_FILE1="${TEMP_DIR}/is_progress_ok_tempfile1"
typeset TEMP_FILE2="${TEMP_DIR}/is_progress_ok_tempfile2"
typeset TEMP_FILE3="${TEMP_DIR}/is_progress_ok_tempfile3"
typeset VERBOSE=' '
typeset WHERE_ADDITION=' '
typeset -u YNIND

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
while getopts a:cmpMSr:v o
do      case "$o" in
        a)      MAIL_RECIPIENT=${OPTARG}
                SEND_MAIL='Y';;
        m)      SEND_MAIL='Y';;
        r)      REMINDER_TIME=${OPTARG}
                SMART_MAIL='Y';;
        M)      SEND_MAIL='A';;
        S)      SMART_MAIL='Y'
                SEND_MAIL='M';;
        v)      VERBOSE='v';;
        [?])    print "${THISSCRIPTNAME}: invalid parameters supplied - ${USAGE}"
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ ${SEND_MAIL} == "A" ]] 
then
    SEND_MAIL='Y'
elif [[ ${SEND_MAIL} == "Y" ]] && [[ ${SMART_MAIL} == "Y" ]]
then
    #########################################################################################
    # Reset the SEND_MAIL value appropriately if both 'S' and 'm or a' parameters are passed
    #########################################################################################
    SEND_MAIL='M'
fi

rm -f ${TEMP_FILE1}
rm -f ${TEMP_FILE2}
rm -f ${MAIL_BUFFER}
rm -f ${OUTPUT_BUFFER}

sqlplus -s ${AMCHECK_TNS} <<- SQL010 > ${TEMP_FILE3} 
	SET PAGES 0 
	SET FEEDBACK OFF
	SELECT column_name FROM all_tab_columns WHERE table_name = 'AM_PROG_SERVER' AND owner = 'AMO' ORDER BY 1; 
	exit;
SQL010
L_RET=$?

##########################
# Process any IND columns
##########################
if [[ $# -gt 0 ]]
then
    set $*
    if [[ $# -gt 0 ]]
    then
         MAIL_TITLE="${MAIL_TITLE}_("
         SPACE=''
    fi
    for PAR in "$@"
    do
        INDCOLUMN=${PAR%+*}
        YNIND=${PAR##*+}
        if [[ `grep -cw ${INDCOLUMN} ${TEMP_FILE3}` -ne 1 ]]
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
            MAIL_TITLE="${MAIL_TITLE}${SPACE}${INDCOLUMN}=${YNIND}"
            SPACE=" "
        fi
    done
    if [[ $# -gt 0 ]]
    then
         MAIL_TITLE="${MAIL_TITLE})"
    fi
fi

# Ping tests

if [[ ${L_RET} -eq 0 ]]
then
sqlplus -s ${AMCHECK_TNS} <<- SQL100 > ${TEMP_FILE1}
	SET PAGES 0
	SET FEEDBACK OFF
	SELECT physical_server FROM amo.am_prog_server WHERE disabled <> 'Y' ${WHERE_ADDITION} ORDER BY run_order ASC;
	exit; 
SQL100
    L_RET=$?
fi
   
if [[ ${L_RET} -ne 0 ]]
then
    print -- "Error obtaining Progress Connection details from AM Checks" | tee -a ${OUTPUT_BUFFER}
    f_redhtml "Error obtaining Progress Connection details from AM Checks" >> ${MAIL_BUFFER}
    ERROR_IND='Y'
else

    cat ${TEMP_FILE1} | sed '/^$/d' | while read SERVER
    do
        print >> ${MAIL_BUFFER}
        ${PING} ${SERVER} >/dev/null 2>&1
        if [[ $? -ne 0 ]]
        then
            MSG="${SERVER} - Ping test ERROR!"
            ERROR_IND='Y'
            print ${MSG} | tee -a ${OUTPUT_BUFFER}
            f_redhtml ${MSG} >> ${MAIL_BUFFER}
        else
            MSG="${SERVER} - Ping test OK."
            print ${MSG} | tee -a ${OUTPUT_BUFFER}
            f_blackhtml ${MSG} >> ${MAIL_BUFFER}
            echo "ssh oracle@${SERVER} 'ksh -s' < ${AMCHECK_DIR}/prog_checks.ksh ${VERBOSE}  2>/dev/null | grep -v logout > ${TEMP_FILE2}"
            ssh oracle@${SERVER} 'ksh -s' < ${AMCHECK_DIR}/prog_checks.ksh ${VERBOSE}  2> ${ERRORFILE} | grep -v logout > ${TEMP_FILE2}
            L_RET=$?
            if [[ ${L_RET} -ne 0 ]]
            then
                ERROR_IND='Y'
                cat ${ERRORFILE} | tee -a ${OUTPUT_BUFFER}
                cat ${ERRORFILE} >> ${MAIL_BUFFER}
            fi

            cat ${TEMP_FILE2} | strings | sed 's/\*/\+/g' | while read LINE
            do
                print ${LINE} | tee -a ${OUTPUT_BUFFER}
                if [[ `echo ${LINE} | grep -c 'NOT OK'` -gt 0 ]] || 
                   [[ `echo ${LINE} | grep -c 'errno'` -gt 0 ]] || 
                   [[ `echo ${LINE} | grep -c 'ERROR'` -gt 0 ]] || 
                   [[ `echo ${LINE} | grep -c 'Error'` -gt 0 ]] 
                then
                    f_redhtml ${LINE} >> ${MAIL_BUFFER}
                    ERROR_IND='Y'
                else
                    f_blackhtml ${LINE} >> ${MAIL_BUFFER}
                 fi
            done
        fi
    done
fi

if [[ ${ERROR_IND} == "Y" ]]
then
    MAIL_TITLE="URGENT ERROR - ${MAIL_TITLE}"
fi

if [[ ! -f ${TEMP_DIR}/${LAST_EMAIL_BUFFER} ]]
then
    echo "wibble" > ${TEMP_DIR}/${LAST_EMAIL_BUFFER}
fi

if [[ ${SEND_MAIL} != "Y" ]] &&
   [[ `diff ${TEMP_DIR}/${LAST_EMAIL_BUFFER} ${OUTPUT_BUFFER} | wc -l` -gt 0 ]] && 
   [[ ${SMART_MAIL} == "Y" ]] 
then
    ############################################################################################################################
    # Would normally send an e-mail but differences may be because one of the runs used the verbose option so don't e-mail if
    # it's smart mail and there are no errors and the previous run was verbose                                          
    ############################################################################################################################
    if [[ ${ERROR_IND} != "Y" ]]  && [[ `grep -c mode ${TEMP_DIR}/${LAST_EMAIL_BUFFER}` -gt 0 ]]
    then
        echo
    else 
        SEND_MAIL="Y"
    fi
else
    LAST_MAIL_COUNT=`find ${TEMP_DIR} -name ${LAST_EMAIL_BUFFER} -mmin +${REMINDER_TIME} | wc -l`
    if [[ ${LAST_MAIL_COUNT} -gt 0 ]] && 
       [[ ${SMART_MAIL} == "Y" ]] &&
       [[ ${ERROR_IND} == "Y" ]]
    then
        SEND_MAIL="Y"
    fi
fi

if [[ ${SEND_MAIL} == "Y" ]]
then
#    echo "debug: Sending mail"
    cp ${OUTPUT_BUFFER}  ${TEMP_DIR}/${LAST_EMAIL_BUFFER}
    f_mail ~/amchecks/is_progress_ok.png Green ${MAIL_RECIPIENT} "${OUTPUT_BUFFER}[Arial]+${MAIL_BUFFER}[Courier]" ${MAIL_TITLE}
#    f_mail ~/amchecks/dance.gif Green ${MAIL_RECIPIENT} "${OUTPUT_BUFFER}[Arial]+${MAIL_BUFFER}[Courier]" ${MAIL_TITLE}
fi

exit 0

