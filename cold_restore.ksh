#!/bin/ksh
#####################################################################################
# Name             : cold_restore.ksh
# Author           : Tony Webb
# Created          : 05 September 2016
# Type             : Korn shell script
# Version          : 010
# Returns          : 0  - Success
#
# Parameters       : None
#
#---------+----------+------------+-----------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+-----------------------------------------------
# 010     | 05/09/16 | T. Webb    | Original
#####################################################################################
#
# INSTRUCTIONS
# ==============
#
# Edit a copy of this script for each restore. This is basically juat a template.
#
# Before running this, ensure the database is shutdown.
# ..and of course, your ORACLE_HOME and ORACLE_SID MUST be correct in THIS session!!
#
# The script below assumes that the controlfiles are also lost. 
# If they are not then you should edit the file to startup MOUNT (not nomount)
# and also remove the 'restore controlfile' and 'alter database mount' commands.
#
# Be sure to EDIT THE FOLLOWING:
#
# i)   The UNTIL TIME to the desired time
# ii)  The correct full pathname for your PFILE
# iii) The correct full pathname for your CONTROLFILE (if restoring)
#
# Watch out for 'smart quotes' if cut-n-pasting!
#
# Remember to open the database with 'RESETLOGS' and recreate the spfile if the 
# restore and recover is successful.
#
# Also, you may want to do a new backup afterwards as you are resetting your logfiles 
# here.
#
#                    MOST IMPORTANTLY ..DON'T RUSH!
#
#####################################################################################

NLS_DATE_FORMAT='Mon DD YYYY HH24:MI:SS'
export NLS_DATE_FORMAT

# Correct hard-coded pfiles and controlfiles in the next bit and change the 'until time' as necessary:

${ORACLE_HOME}/bin/rman target / catalog rman/change_this@RMAN_TNS_ALIAS <<EOF1

run {
  startup pfile='/u01/app/oracle/backup/rman/CMWMAX/CMWMAX_PFILE_06092016_MONTH.ora' nomount;
  restore controlfile from '/u01/app/oracle/backup/rman/CMWMAX/CMWMAX_controlfile_10_1_921837556.ctl';
  alter database mount;
  set until time "to_date('06-SEP-2016 09:58:00','DD-MON-YYYY HH24:MI:SS')";
  restore database;
  recover database;
  }
EOF1

echo "If successful run ALTER DATABASE OPEN RESETLOGS and recreate the spfile"

exit 0

