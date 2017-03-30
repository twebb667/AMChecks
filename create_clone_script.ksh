#!/bin/ksh
##################################################################################
# Name             : create_clone_script.ksh
# Author           : Tony Webb
# Created          : 04 Jul 2016 (Happy Birthday USA!)
# Type             : Korn shell script
# Version          : 010
# Parameters       : -f (forced overwrite of script)
#                    -p parent database_connect_string
#                    -c clone database_connect_string
#
# Returns          : 0   Success
#                    50  Wrong parameters
#
# Notes            : Note that flags are used but the '-p' and '-c' are NOT optional!
#                    Positional parameters are not used in case the wrong order is 
#                    used.
#                    Database access will be via the 'AMU' account.
#                    Currently this script only works on pre-existing clones.
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | 04/07/16 | T. Webb    | Original
##################################################################################
#

#AMCHECK Directories
typeset AMCHECK_DIR=~oracle/amchecks
typeset TEMP_DIR=/tmp/amchecks

typeset CLONE
typeset CLONE_SIZE=0
typeset DATE=`date '+%d/%m/%y'`
typeset DATESTAMP=`date '+%y%m%d%H%M'`
typeset DIRECTORY A50
typeset DBSIZE
typeset DFSIZE
typeset -R20 DBSIZESTRING
typeset -R20 DFSIZESTRING
typeset HASHLINE="###############################################################################################################"
typeset NLS_DATE_FORMAT='Mon DD YYYY HH24:MI:SS'
export  NLS_DATE_FORMAT
typeset PARENT
typeset PARENT_SIZE=0
typeset RUNDATE=`date +'%d-%^b-%Y %H:%M:%S'`
typeset THISSCRIPTNAME=`basename $0`
typeset USAGE="Incorrect Usage. TO FIX run: ${THISSCRIPTNAME}\n -p database (parent db)\n -c database (clone db)\n -u (clone must be up)\n
(database should be user/pwd@db with user normally being sys)\n"

##################
# Local Functions
##################

function f_sizebydirectory
{
    typeset SID=$1

	sqlplus -s ${CONNECT}\@${SID} <<- SQL010
	SET PAGES 0 
	SET FEEDBACK OFF
	col directory format a50
	col meg format 999,999,990

	SELECT SUBSTR(file_name, 1, INSTR(file_name, '/',-1)-1) AS directory, SUM(bytes)/1024/1024 AS meg
	FROM (	SELECT file_name, bytes FROM dba_data_files
		UNION ALL
		SELECT file_name, bytes FROM dba_temp_files
		UNION ALL
		SELECT f.member, g.bytes FROM v\$log g, v\$logfile f WHERE f.group# = g.group#
		UNION ALL
		SELECT name, block_size*file_size_blks
		FROM v\$controlfile)
		GROUP BY SUBSTR(file_name, 1, INSTR(file_name, '/',-1)-1)
	ORDER BY directory;
	exit;
SQL010

    if [[ $? -ne 0 ]]
    then
    	echo ${HASHLINE}
    	echo "Problems querying ${SID}"
    	echo -e "${USAGE}"
    	echo ${HASHLINE}
    	exit 65
    fi
}

function f_totaldbsize
{
    typeset SID=$1
    typeset -i SIZE=0

	SIZE=`sqlplus -s ${CONNECT}\@${SID} <<- SQL010
	SET PAGES 0 
	SET FEEDBACK OFF
	SELECT SUM(bytes)/1024/1024 AS Meg
	FROM (	SELECT SUM(bytes) AS bytes FROM dba_data_files
		UNION ALL
		SELECT SUM(bytes) FROM dba_temp_files
		UNION ALL
		SELECT SUM(g.bytes) FROM v\\\$log g, v\\\$logfile f WHERE f.group# = g.group#
		UNION ALL
		SELECT SUM(block_size*file_size_blks)
		FROM v\\\$controlfile); 
	exit;
SQL010
`  
    if [[ $? -ne 0 ]]
    then
    	echo ${HASHLINE}
    	echo "Problems querying ${SID}"
    	echo -e "${USAGE}"
    	echo ${HASHLINE}
    	exit 66
    fi

     printf "%'d\n" ${SIZE}   
}

######
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

while getopts c:p: o
do      case "$o" in
        c)      CLONE="${OPTARG}";;
        p)      PARENT="${OPTARG}";;
        [?])    echo ${HASHLINE}
		echo -e "${THISSCRIPTNAME}: invalid parameters supplied \n${USAGE}"
                echo ${HASHLINE}
                exit 50;;
        esac
done
shift `expr ${OPTIND} - 1`

if [[ -z ${PARENT} ]]
then
    echo ${HASHLINE}
    echo "Please specify a parent (db to copy from) connect string e.g. sys/change_on_install@ORCL"
    echo -e "${USAGE}"
    echo ${HASHLINE}
    exit 61
fi

if [[ -z ${CLONE} ]]
then
    echo ${HASHLINE}
    echo "Please specify a child/clone connect string e.g. sys/cange_on_install@ORCL"
    echo -e "${USAGE}"
    echo ${HASHLINE}
    exit 62
fi

# Validate connect string for parent:

typeset PARENT_UPW=${PARENT%%@*}
typeset PARENT_DB=${PARENT##*@}
typeset CLONE_UPW=${CLONE%%@*}
typeset CLONE_DB=${CLONE##*@}

tnsping ${PARENT_DB} > /dev/null
if [[ $? -ne 0 ]]
then
    echo ${HASHLINE}
    echo "Cannot tnsping parent database: ${PARENT_DB}. Aborting.."
    echo -e "${USAGE}"
    echo ${HASHLINE}
    exit 63
fi

tnsping ${CLONE_DB} > /dev/null
if [[ $? -ne 0 ]]
then
    echo ${HASHLINE}
    echo "Cannot tnsping clone database: ${CLONE_DB}. Please correct or start a listener. Aborting.."
    echo -e "${USAGE}"
    echo ${HASHLINE}
    exit 64
fi

PARENT_SIZE=`f_totaldbsize ${PARENT_DB}`
echo "Total database sizes(parent):  ${PARENT_DB} is ${PARENT_SIZE} Meg" > /tmp/parentsize
echo " " >> /tmp/parentsize
echo "Directory                Space used (DB Size)" >> /tmp/parentsize
echo "----------------------   --------------------" >> /tmp/parentsize
f_sizebydirectory ${PARENT_DB} > /tmp/parent
cat /tmp/parent | while read LINE
do
    set ${LINE}
    DIRECTORY=${1}
    DBSIZE=${2}
    DBSIZESTRING="${DBSIZE} Meg"
    echo "${DIRECTORY}    ${DBSIZESTRING}" >> /tmp/parentsize
done
PARENT_SIZE_FILE=`cat /tmp/parentsize`

CLONE_SIZE=`f_totaldbsize ${CLONE_DB}`
echo " " > /tmp/clonesize
echo "Total database sizes (clone):  ${CLONE_DB} is ${CLONE_SIZE} Meg" >> /tmp/clonesize
echo " " >> /tmp/clonesize
echo "Directory                Space used (DB Size)     Space Free (from df)" >> /tmp/clonesize
echo "----------------------   --------------------     --------------------" >> /tmp/clonesize
f_sizebydirectory ${CLONE_DB} > /tmp/clone
cat /tmp/clone | while read LINE
do
    set ${LINE}
    DIRECTORY=${1}
    DBSIZE=${2}
    DBSIZESTRING="${DBSIZE} Meg"
    DFSIZE=$(( `df -Pk ${DIRECTORY} | tail -1 | awk '{print $4}'`/1024 ))
    DFSIZESTRING=`printf "%'d Meg\n" ${DFSIZE}`
    echo "${DIRECTORY}    ${DBSIZESTRING}     ${DFSIZESTRING}" >> /tmp/clonesize
done
CLONE_SIZE_FILE=`cat /tmp/clonesize`

# Construct LOGFILE stuff from existing clone
	
sqlplus -s ${CONNECT}\@${CLONE_DB} <<- SQL090 >/dev/null
	SET PAGES 0 
	SET FEEDBACK OFF
	SET LINES 130
	col directory format a50
	SPOOL /tmp/logfilebit.lst
	SELECT a.wibble || ' SIZE ' || z.bytes/1024/1024 || 'M,'
	FROM (SELECT group#, '  GROUP ' || group# || ' (' || LISTAGG('''' || member || '''', ', ') WITHIN GROUP (ORDER BY member) || ')' AS wibble FROM v\$logfile
	WHERE group# <> (SELECT MAX(group#) FROM v\$log) GROUP BY group#) a, v\$log z
	WHERE a.group# = z.group#;
	exit;
SQL090

LOGFILE_STUFF=`cat /tmp/logfilebit.lst | sed '$s/M,/M;/'`

cat > ${TEMP_DIR}/clone_${PARENT_DB}_to_${CLONE_DB}.ksh <<- KSH01
#!/bin/ksh
##################################################################################
# Shell script wrapper for an rman clone - creating ${CLONE_DB} from ${PARENT_DB}
#
# Type: ksh script
#
#---------+----------+------------+---------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+---------------------------------------------
# 010     | ${DATE} |            | Original
##################################################################################
THIS_DATESTAMP=\`date '+%y%m%d%H%M'\`
 
`which rman` << EOF
spool log to '${TEMP_DIR}/clone_${PARENT_DB}_to_${CLONE_DB}.log.\${THIS_DATESTAMP}'
export ORAENV_ASK=NO
export ORACLE_SID=${CLONE_DB}
. oraenv

connect target ${PARENT}
connect ${CLONE_UPW}
run
{
set until time "to_date('${RUNDATE}','DD-MON-YYYY HH24:MI:SS')";

allocate channel c1 type disk;
allocate AUXILIARY channel acd1 type disk;
duplicate target database to '${ORACLE_SID}'

#db_file_name_convert=('${PARENT_DB}/directory1', '${CLONE_DB}/directory1', '${PARENT_DB}/directory2', '${CLONE_DB}/directory2'...)
logfile
${LOGFILE_STUFF}
}
EOF

exit

################################################################################################
# Use the information below to edit and complete the db_file_name_convert value in your script. 
# I think this needs to remain a manual process..
# You might want to edit the 'UNTIL TIME' above too..
################################################################################################

${PARENT_SIZE_FILE}
${CLONE_SIZE_FILE}
KSH01

chmod 744 ${TEMP_DIR}/clone_${PARENT_DB}_to_${CLONE_DB}.ksh 
echo " "
echo "Now edit and run the generated file: ${TEMP_DIR}/clone_${PARENT_DB}_to_${CLONE_DB}.ksh "
echo " "
exit

