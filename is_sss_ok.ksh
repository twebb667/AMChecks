#!/bin/ksh
##################################################################################
# Name             : is_sss_ok
# Author           : Tony Webb
# Created          : 19 Feb 2016
# Type             : Korn shell script
# Version          : 010
# Parameters       : -m (mail)
#                    -M (always send mail)
#                    -c (cron)
#                    -S (smart mail)
#
# Returns          : 0   Success
#                    50  Wrong parameters
#
# Notes            : 
#
#---------+----------+------------+----------------------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+----------------------------------------------------------
# 010     | 19/02/16 | T. Webb    | Original
#############################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -m (mail) -c (cron) -S minutes (smart mail)"

typeset MAIL_BUFFER="${TEMP_DIR}/is_sss_ok_mail"
#typeset MAIL_RECIPIENT is set in external include file
typeset MAIL_TITLE="SQL Server Connectivity Test"
typeset NEW_INSTANCE
typeset OUTPUT_BUFFER="${TEMP_DIR}/is_sss_ok_output"
typeset PING='/bin/ping -c1 -t2'
typeset QUERY='".tables"'
typeset SEND_MAIL='N'
typeset SMART_MAIL='N'
typeset TEMP_FILE1="${TEMP_DIR}/is_sss_ok_tempfile1"
typeset TEMP_FILE2="${TEMP_DIR}/is_sss_ok_tempfile2"
typeset TEMP_FILE3="${TEMP_DIR}/is_sss_ok_check.ksh"
typeset TEMP_FILE4="${TEMP_DIR}/is_sss_ok_tempfile4"
typeset -u URGENT_IND='N'

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
while getopts a:cmMS o
do      case "$o" in
        a)      MAIL_RECIPIENT=${OPTARG}
                SEND_MAIL='Y';;
        m)      SEND_MAIL='Y';;
        M)      SEND_MAIL='A';;
        S)      SMART_MAIL='Y'
                SEND_MAIL='M';;
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
rm -f ${TEMP_FILE3}

sqlplus -s ${AMCHECK_TNS} <<- SQL100 > ${TEMP_FILE1}
	set pages 0
	set feedback off
	select server from amo.ss_instance where disabled <> 'Y' AND instance_name IS NULL UNION select server || '++' || instance_name from amo.ss_instance where disabled <> 'Y' AND instance_name IS NOT NULL ORDER BY 1;
	exit; 
SQL100
    
if [[ $? -ne 0 ]]
then
    print -- "Error obtaining SQL Server Connection details from AM Checks"
else
    cat ${TEMP_FILE1} | sed '/^$/d' | while read INSTANCE
    do
        NEW_INSTANCE=`echo ${INSTANCE} | tr '+' '\\' 2> /dev/null`
        print -- "print -n -- 'Connecting to ${NEW_INSTANCE} '" >> ${TEMP_FILE2} 
        print -- "mssql -s ${INSTANCE} -u amu -p gl1tterbug -d master -q ${QUERY} >/dev/null" >> ${TEMP_FILE2}
        print -- "if [[ \$? -eq 0 ]] " >> ${TEMP_FILE2}
        print -- "then"  >> ${TEMP_FILE2}
        print -- "    print -- '..OK'" >> ${TEMP_FILE2}
        print -- "fi"  >> ${TEMP_FILE2}
    
        cat ${TEMP_FILE2} | tr '+' '\' > ${TEMP_FILE3} 2>/dev/null
    done

    chmod 700 ${TEMP_FILE3}
    echo "Running ${TEMP_FILE3}"
    rm -f ${MAIL_BUFFER}
    rm -f ${OUTPUT_BUFFER}
    ${TEMP_FILE3} > ${TEMP_FILE4} 2>&1
fi

cat ${TEMP_FILE4} | while read LINES
do
    if [[ `print -- ${LINES} | egrep -ic 'ERROR|FAIL'` -gt 0 ]]
    then
        export GREP_COLOR='01;31' # bold red
        print -- ${LINES} | sed 's/Connecting/Error Connecting/' | egrep -iw --color=always 'ERROR|FAIL|FAILED' >> ${OUTPUT_BUFFER}
        f_redhtml ${LINES} >> ${MAIL_BUFFER}

        if [[ ${SEND_MAIL} == "M" ]]
        then
            SEND_MAIL='Y'
        fi
        if [[ ${URGENT_IND} != 'Y' ]]
        then
            URGENT_IND='Y'
            MAIL_TITLE="URGENT ${MAIL_TITLE}"
        fi
    else
        f_blackhtml ${LINES} >> ${MAIL_BUFFER}
        print -- ${LINES}  >> ${OUTPUT_BUFFER}
    fi
done

cat ${OUTPUT_BUFFER}

if [[ ${SEND_MAIL} == "Y" ]]
then
#    f_mail SQL_Server_Connectivity green ${MAIL_RECIPIENT} ${MAIL_BUFFER} ${MAIL_TITLE}
    f_mail ~/amchecks/is_oracle_ok.gif green ${MAIL_RECIPIENT} 'null'+${MAIL_BUFFER} ${MAIL_TITLE}
fi

exit 0

