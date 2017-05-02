#!/bin/ksh
##################################################################################
# Name             : sss_space.ksh
# Author           : Tony Webb
# Created          : 23 Feb 2017
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
# Notes            : user amu will need the following granted:
#
#                    GRANT VIEW ANY DEFINITION TO amu
#                    GO
#
#---------+----------+------------+----------------------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+----------------------------------------------------------
# 010     | 23/02/17 | T. Webb    | Original
#############################################################################################

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME} -m (mail) -c (cron) -S minutes (smart mail)"

typeset MAIL_BUFFER="${TEMP_DIR}/is_sss_ok_mail"
#typeset MAIL_RECIPIENT is set in external include file
typeset MAIL_TITLE="SQL Server Space Report"
typeset NEW_INSTANCE
typeset OUTPUT_BUFFER="${TEMP_DIR}/is_sss_ok_output"
typeset PING='/bin/ping -c1 -t2'

typeset QUERY='"SELECT DB_NAME(db.database_id) DatabaseName, (CAST(mfrows.RowSize AS FLOAT)*8)/1024 RowSizeMB, (CAST(mflog.LogSize AS FLOAT)*8)/1024  LogSizeMB FROM sys.databases db LEFT JOIN (SELECT database_id, SUM(size) RowSize FROM  sys.master_files WHERE type = 0 GROUP BY database_id, type) mfrows ON mfrows.database_id = db.database_id LEFT JOIN (SELECT database_id, SUM(size) LogSize FROM  sys.master_files WHERE type = 1 GROUP BY database_id, type) mflog ON mflog.database_id = db.database_id;"'

#typeset QUERY='" DECLARE @spacetable table ( database_name varchar(500) , total_size_data int, space_util_data int, space_data_left int, percent_fill_data float, total_size_data_log int, space_util_log int, space_log_left int, percent_fill_log char(50), [total db size] int, [total size used] int, [total size left] int) insert into  @spacetable EXECUTE master.sys.sp_MSforeachdb 'USE [?]; select x.[DATABASE NAME],x.[total size data],x.[space util],x.[total size data]-x.[space util] [space left data], x.[percent fill],y.[total size log],y.[space util], y.[total size log]-y.[space util] [space left log],y.[percent fill], y.[total size log]+x.[total size data] ''total db size'' ,x.[space util]+y.[space util] ''total size used'', (y.[total size log]+x.[total size data])-(y.[space util]+x.[space util]) ''total size left'' from (select DB_NAME() ''DATABASE NAME'', sum(size*8/1024) ''total size data'',sum(FILEPROPERTY(name,''SpaceUsed'')*8/1024) ''space util'' ,case when sum(size*8/1024)=0 then ''less than 1% used'' else substring(cast((sum(FILEPROPERTY(name,''SpaceUsed''))*1.0*100/sum(size)) as CHAR(50)),1,6) end ''percent fill'' from sys.master_files where database_id=DB_ID(DB_NAME())  and  type=0 group by type_desc  ) as x , (select sum(size*8/1024) ''total size log'',sum(FILEPROPERTY(name,''SpaceUsed'')*8/1024) ''space util'' ,case when sum(size*8/1024)=0 then ''less than 1% used'' else substring(cast((sum(FILEPROPERTY(name,''SpaceUsed''))*1.0*100/sum(size)) as CHAR(50)),1,6) end ''percent fill'' from sys.master_files where database_id=DB_ID(DB_NAME())  and  type=1 group by type_desc  )y' select * from @spacetable order by database_name;"' typeset SEND_MAIL='N' typeset SMART_MAIL='N' typeset TEMP_FILE1="${TEMP_DIR}/is_sss_ok_tempfile1" typeset TEMP_FILE2="${TEMP_DIR}/is_sss_ok_tempfile2" typeset TEMP_FILE3="${TEMP_DIR}/is_sss_ok_check.ksh" typeset TEMP_FILE4="${TEMP_DIR}/is_sss_ok_tempfile4" 

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
    rm -f /tmp/amchecks/tony
    cat ${TEMP_FILE1} | sed '/^$/d' | while read INSTANCE
    do
        NEW_INSTANCE=`echo ${INSTANCE} | tr '+' '\\' 2> /dev/null`
        print -- "print -- 'Connecting to ${NEW_INSTANCE} ' | tee -a /tmp/amchecks/tony" >> ${TEMP_FILE2} 
        print -- "mssql -s ${INSTANCE} -u amu -p change_this -d master -q ${QUERY} >>/tmp/amchecks/tony" >> ${TEMP_FILE2}
    
        cat ${TEMP_FILE2} | tr '+' '\' > ${TEMP_FILE3} 2>/dev/null
    done

    chmod 700 ${TEMP_FILE3}
    echo "Running ${TEMP_FILE3}"
    rm -f ${MAIL_BUFFER}
    rm -f ${OUTPUT_BUFFER}
    ${TEMP_FILE3} > ${TEMP_FILE4} 2>&1
fi

##cat /tmp/amchecks/tony| while read LINES
##do
##        f_blackhtml ${LINES} >> ${MAIL_BUFFER}
##        print -- ${LINES}  >> ${OUTPUT_BUFFER}
##done
cp /tmp/amchecks/tony ${MAIL_BUFFER}
cp /tmp/amchecks/tony ${OUTPUT_BUFFER}

MAIL_RECIPIENT="fred.flintstone@bedrock.com"
cat ${OUTPUT_BUFFER}

if [[ ${SEND_MAIL} == "Y" ]]
then
    f_mail SQL_Server_Space green ${MAIL_RECIPIENT} ${MAIL_BUFFER} ${MAIL_TITLE}
#    f_mail ~/amchecks/is_oracle_ok.gif green ${MAIL_RECIPIENT} 'null'+${MAIL_BUFFER} ${MAIL_TITLE}
fi

exit 0

