#!/bin/ksh
##################################################################################
# Name             : functions.ksh
# Author           : Tony Webb
# Created          : 17 June 2014
# Type             : Korn shell script
# Version          : 110
# Parameters       : none
# Returns          : none
#
# Notes            : 
#
#---------+----------+------------+------------------------------------------------
# VERSION |DATE      | BY         | REASON
#---------+----------+------------+------------------------------------------------
# 010     | 17/06/14 | T. Webb    | Original
# 020     | 01/09/14 | T. Webb    | html changes
# 030     | 13/04/15 | T. Webb    | f_gethost added
# 040     | 08/05/15 | T. Webb    | inline text option added
# 050     | 22/05/15 | T. Webb    | Background colours added
# 060     | 18/06/15 | T. Webb    | Better handling of non-attachments (f_mail)
# 070     | 19/06/15 | T. Webb    | f_mail font parameterised
# 080     | 17/07/15 | T. Webb    | f_mail "importance" included
# 090     | 04/12/15 | T. Webb    | 'URGENT ' processing added
# 100     | 23/12/16 | T. Webb    | Sorted out spurious 'empty' attachments (f_mail)
# 110     | 06/01/17 | T. Webb    | Removed unwanted underscores (f_mail)
#####################################################################################

#############
# Functions
#############

##################################
# Formatting functions (terminal)
##################################

function f_blueprint    
{                  
    print -- "$(tput setaf 4)${*}$(tput sgr 0)"
}

function f_boldprint    
{                  
    print -- "$(tput sgr 1)${*}$(tput sgr 0)"
}

function f_gethost
{
    ########################################################################
    # First parameter is the SID; Second parameter is the tnsnames.ora file
    ########################################################################

    grep $1 $2 -A6 | grep -i host | cut -d'=' -f4 | cut -d ')' -f1 | cut -d'.' -f1 | sort -u | sed 's/ //' | tr -d '\r\n'

}

function f_greenprint    
{                  
    print -- "$(tput setaf 2)${*}$(tput sgr 0)"
}

function f_greenstar
{
    typeset -i LOOPER=0
    typeset -i STRLEN
    typeset STRLEN=`echo ${*} | wc -c`
    typeset UNDERLINE=''
    tput setaf 2

    while [[ ${LOOPER} -le ${STRLEN} ]];
    do
        UNDERLINE=${UNDERLINE}"#"
        let LOOPER+=1
    done
    print -- ${UNDERLINE}
    print -- "${*}"
    print -- ${UNDERLINE}
    tput sgr 0
}

function f_magentaprint    
{                  
    print -- "$(tput setaf 5)${*}$(tput sgr 0)"
}

function f_cyanprint    
{                  
    print -- "$(tput setaf 6)${*}$(tput sgr 0)"
}

function f_redprint    
{                  
    print -- "$(tput setaf 1)${*}$(tput sgr 0)"
}

function f_yellowprint    
{                  
    print -- "$(tput setaf 3)${*}$(tput sgr 0)"
}

##############################
# Formatting functions (html)
##############################

function f_blackhtml    
{                  
    print -- "<font size=1 face=Terminal color=black>${*}</font>" 
}

function f_bluehtml    
{                  
    print -- "<font size=1 face=Terminal color=blue>${*}</font>" 
}

function f_blueboldhtml    
{                  
    print -- "<font size=1 face=Terminal color=blue><b>${*}</b></font>" 
}

function f_boldhtml    
{                  
    print -- "<font size=1 face=Terminal color=black><b>${*}</b></font>" 
}

function f_cyanhtml    
{                  
    print -- "<font size=1 face=Terminal color=cyan>${*}</font>" 
}

function f_greenhtml    
{                  
    print -- "<font size=1 face=Terminal color=green>${*}</font>" 
}

function f_greenboldhtml    
{                  
    print -- "<font size=1 face=Terminal color=green><b>${*}</b></font>" 
}

function f_magentahtml    
{                  
    print -- "<font size=1 face=Terminal color=magenta>${*}</font>" 
}

function f_redhtml    
{                  
    print -- "<font size=1 face=Terminal color=red>${*}</font>" 
}

function f_redboldhtml    
{                  
    print -- "<font size=1 face=Terminal color=red><b>${*}</b></font>" 
}

function f_yellowhtml    
{                  
    print -- "<font size=1 face=Terminal color=yellow>${*}</font>" 
}

function f_mail
{
    ###########################################################################################
    #
    # Content ID is obviously made up. Feel free to replace it accordingly. 
    # You'll probably want to use your own branding anyhow.
    #
    # Note that calls to this function should consist of 5 parameters:
    #
    # 1) Filename (for a graphic) including extension or a title where words are 
    #    separated by underscore. The name of this file is important as the filename
    #    without the extension will be used as the header in the attachment. If the
    #    filename has an underscore then it will be replaced by a space character.
    # 2) HTML format colour for the title text (including date). 
    #    N.B. If using #number format then put this parameter in double-quotes
    #    otherwise the hash screws up formatting of parameters.
    # 3) Address of e-mail recipient (multiple allowed if delimited by ',' and no space)
    # 4) File to be parsed and formatted (optionally with '+inline_file').
    #    The file is expected to be an attachment. If you want text inline this can be placed
    #    in an additional file and this file needs to be added to the parameter with a '+'
    #    e.g. html_filename+inline_filename.
    #    To change the background colour for either file, add a colour in brackets without
    #    spaces e.g. "attachment.html(red)+inline.html(green)" 
    #    Use 'null' for attachment filename to ommit the actual attachment
    #    A second optional set of brackets, but this time square brackets,
    #    can be used to change the fontname for the inline or attached file and a third set
    #    of brackets, but this time curly brackets(!) can be used to change the font colour.
    #    I may get around to allowing font size to change ..one day :-)
    # 5) Subject for the e-mail
    #
    # Parameters up until the last one need to be separated by spaces so be 
    # careful how you call this function.
    #
    # Example usage:
    #  f_mail my_heading blue ${MAIL_RECIPIENT} ${MAIL_BUFFER} ${MAIL_TITLE}
    #  f_mail ~/amchecks/amchecks.png "#660066" ${MAIL_RECIPIENT} ${MAIL_BUFFER} ${MAIL_TITLE}
    #  f_mail Space_Summary blue ${MAIL_RECIPIENT} 'null'+${MAIL_BUFFER} ${MAIL_TITLE}
    #  f_mail ~/amchecks/is_oracle_ok.gif "#702EBF" ${MAIL_RECIPIENT} ${MAIL_BUFFER}("red")+${INLINE_FILE}("blue") ${MAIL_TITLE}
    #  f_mail ~/amchecks/is_oracle_ok.gif "#702EBF" ${MAIL_RECIPIENT} ${MAIL_BUFFER}("red"){"green"}+${INLINE_FILE}("blue"){"white"} ${MAIL_TITLE}
    #
    ###########################################################################################

    # parse parameters

    typeset TITLE_DETAILS=${1}
    typeset COLOUR=${2}
    typeset TO_ADDRESS=${3}

    typeset ATTACHMENT_FILE_PLUS_COLOUR=${4%+*}
    typeset ATTACHMENT_FILE=`echo ${ATTACHMENT_FILE_PLUS_COLOUR} | cut -d'(' -f1 | cut -d'[' -f1`
    typeset ATTACHMENT_COLOUR=`echo ${ATTACHMENT_FILE_PLUS_COLOUR##*\(} | cut -d')' -f1`
    typeset ATTACHMENT_FONT=`echo ${ATTACHMENT_FILE_PLUS_COLOUR##*\[} | cut -d']' -f1`
    typeset ATTACHMENT_FONT_COLOUR=`echo ${ATTACHMENT_FILE_PLUS_COLOUR##*\{} | cut -d'}' -f1`
    if [[ "${ATTACHMENT_FILE_PLUS_COLOUR}" == "${ATTACHMENT_COLOUR}" ]] || [[ -z ${ATTACHMENT_COLOUR} ]]
    then
        ATTACHMENT_COLOUR="white"
    fi
    if [[ "${ATTACHMENT_FONT}" == "${ATTACHMENT_FILE_PLUS_COLOUR}" ]] || [[ -z ${ATTACHMENT_FONT} ]]
    then
        ATTACHMENT_FONT="courier"
    fi
    if [[ "${ATTACHMENT_FONT_COLOUR}" == "${ATTACHMENT_FILE_PLUS_COLOUR}" ]] || [[ -z ${ATTACHMENT_FONT_COLOUR} ]]
    then
        ATTACHMENT_FONT_COLOUR="black"
    fi

    typeset INLINE_FILE_PLUS_COLOUR=${4##*+}
    typeset INLINE_FILE=`echo ${INLINE_FILE_PLUS_COLOUR} | cut -d'(' -f1 | cut -d'[' -f1`
    typeset INLINE_COLOUR=`echo ${INLINE_FILE_PLUS_COLOUR##*\(} | cut -d')' -f1`
    typeset INLINE_FONT=`echo ${INLINE_FILE_PLUS_COLOUR##*\[} | cut -d']' -f1`
    typeset INLINE_FONT_COLOUR=`echo ${INLINE_FILE_PLUS_COLOUR##*\{} | cut -d'}' -f1`
    if [[ "${INLINE_FILE_PLUS_COLOUR}" == "${INLINE_COLOUR}" ]] || [[ -z ${INLINE_COLOUR} ]]
    then
        INLINE_COLOUR="white"
    fi
    if [[ "${INLINE_FONT}" == "${INLINE_FILE_PLUS_COLOUR}" ]] || [[ -z ${INLINE_FONT} ]]
    then
        INLINE_FONT="courier"
    fi
    if [[ "${INLINE_FONT_COLOUR}" == "${INLINE_FILE_PLUS_COLOUR}" ]] || [[ -z ${INLINE_FONT_COLOUR} ]]
    then
        INLINE_FONT_COLOUR="black"
    fi

    shift 4

#    echo "debug ATTACHMENT_FILE_PLUS_COLOUR ${ATTACHMENT_FILE_PLUS_COLOUR}"
#    echo "debug ATTACHMENT_FILE ${ATTACHMENT_FILE}"
#    echo "debug ATTACHMENT_FONT ${ATTACHMENT_FONT}"
#    echo "debug ATTACHMENT_COLOUR ${ATTACHMENT_COLOUR}"
#    echo "debug ATTACHMENT_FONT_COLOUR ${ATTACHMENT_FONT_COLOUR}"
#    echo "."
#    echo "debug INLINE_FILE_PLUS_COLOUR ${INLINE_FILE_PLUS_COLOUR}"
#    echo "debug INLINE_FILE ${INLINE_FILE}"
#    echo "debug INLINE_FONT ${INLINE_FONT}"
#    echo "debug INLINE_COLOUR ${INLINE_COLOUR}"
#    echo "debug INLINE_FONT_COLOUR ${INLINE_FONT_COLOUR}"
#    echo "."

    typeset SUBJECT=${*}

    typeset AMC_LINE1=""
    typeset AMC_LINE2=" "
    typeset AMC_LINE3=" "
    typeset ATTACH_FILE="/tmp/$$.html"
    typeset CELL1
    typeset FILE_EXTENSION="${TITLE_DETAILS##*.}"
    typeset IMAGE_HTML1=""
    typeset IMAGE_HTML2=""
    typeset IMAGE_HTML3=""
    typeset IMAGE_HTML4=""
    typeset IMAGE_HTML5=""
    typeset IMAGE_HTML6=""
    typeset IMAGE_HTML7=""
    typeset IMAGE_HTML8=""
    typeset IMAGE_HTML9=""
    typeset IMPORTANCE="Normal"
    typeset TITLE_TYPE    

    if [[ ! -z ${FROM_ADDRESS} ]]
    then
        FROM=${FROM_ADDRESS}
    else
	FROM="fred.flintstone@bedrock.com"
    fi
#    echo "debug ATTACH_FILE ${ATTACH_FILE}"
#    echo "debug FILE_EXTENSION ${FILE_EXTENSION}"

    if [[ ${FILE_EXTENSION} = ${TITLE_DETAILS} ]]  && [[ ${ATTACHMENT_FILE} != "null" ]]
    then
        TITLE_DETAILS=`echo ${TITLE_DETAILS} | sed '/_/s// /g'`
	CELL1="<td align='left'><font size=4 face=${INLINE_FONT} color=${COLOUR}><b>${TITLE_DETAILS}</b></font></td>"
        IMAGE_HTML7="Content-Transfer-Encoding: base64"
	AMC_LINE1A=" "
        TITLE_TEXT=${TITLE_DETAILS}
    else
	AMC_LINE1A="--AMC"
        CELL1="<td align='left'><img src=\"cid:part1.0123456789.9876543210\" alt=\"\"></td>"
	typeset -u TITLE_TEXT=`basename ${TITLE_DETAILS%%.*} | tr '_' ' '`
        IMAGE_HTML1="Content-Type: image/${FILE_EXTENSION};name=\"${TITLE_DETAILS}\""
	IMAGE_HTML2="Content-Transfer-Encoding: base64"
	IMAGE_HTML3="Content-ID: <part1.0123456789.9876543210>"
	IMAGE_HTML4="Content-Disposition: inline; filename=\"${TITLE_DETAILS}\""
        IMAGE_HTML5="$(base64 ${TITLE_DETAILS})"
    fi

    ################################################
    # Wrap some html around the file to be e-mailed.
    ################################################
    echo " <html>" > ${ATTACH_FILE}  
    echo " <head>" >> ${ATTACH_FILE}  
    echo " <meta http-equiv=\"content-type\" content=\"text/html; charset=ISO-8859-15\">" >> ${ATTACH_FILE}  
    echo " </head>" >> ${ATTACH_FILE}  
    echo " <div align=\"left\">" >> ${ATTACH_FILE}  
    echo " <table width=100%>" >> ${ATTACH_FILE}  
    echo " <tr>" >> ${ATTACH_FILE}  
    echo " <td align='left'><font size=4 face=${ATTACHMENT_FONT} color=${COLOUR}><b>${TITLE_TEXT}</b></font></td>" >> ${ATTACH_FILE}
    echo " <td align='right'><font size=4 face=${ATTACHMENT_FONT} color=${COLOUR}><b>`date +'%a %e %b %R'`</b></font></td>" >> ${ATTACH_FILE}  
    echo " </tr>" >> ${ATTACH_FILE}  
    echo " </table>" >> ${ATTACH_FILE}  
    echo " </div>" >> ${ATTACH_FILE}  
    echo " <body bgcolor=\"${ATTACHMENT_COLOUR}\" text=\"#000000\">" >> ${ATTACH_FILE}  
    echo " <font size=2 face=${ATTACHMENT_FONT} color=${ATTACHMENT_FONT_COLOUR}>" >> ${ATTACH_FILE}  
    echo " <pre>" >> ${ATTACH_FILE}  

    if [[ ${ATTACHMENT_FILE} != "null" ]]
    then
    `cat  ${ATTACHMENT_FILE} |
        	while read HTML
        	do
          	echo "${HTML}" >> ${ATTACH_FILE}  
        	done`  
        echo "  </pre>
     	        </font>
	        </body>" >> ${ATTACH_FILE}  
        IMAGE_HTML6="Content-Type: text/html;name=\"${ATTACH_FILE}\""
        IMAGE_HTML8="Content-Disposition: attachment; filename=\"${ATTACH_FILE}\""
        IMAGE_HTML9="$(base64 ${ATTACH_FILE})"
    fi

    if [[ ${ATTACHMENT_FILE} != "null" ]] || [[ ${FILE_EXTENSION} != ${TITLE_DETAILS} ]]  
    then
        CONTENT_TYPE='Content-Type: multipart/mixed;boundary="AMC"'
        IMAGE_HTML7="Content-Transfer-Encoding: base64"
	AMC_LINE1="--AMC"
	AMC_LINE2="Content-Type: text/html; charset=ISO-8859-15"
	AMC_LINE3="Content-Transfer-Encoding: 7bit"
    else
        CONTENT_TYPE="Content-Type: text/html; charset=ISO-8859-15"
    fi

    if [[ `echo ${SUBJECT} | grep -c 'ERROR'` -gt 0 ]]
    then
        IMPORTANCE="High"
    fi
   
    ######################################################################################
    # If title has 'URGENT ' in it, make the e-mail important but remove the word itself.
    # Note the use of a trailing space.
    ######################################################################################

    if [[ `echo ${SUBJECT} | grep -c 'URGENT '` -gt 0 ]]
    then
        IMPORTANCE="High"
        SUBJECT=`echo ${SUBJECT} | sed 's/URGENT //'`
    fi

        SUBJECT=`echo ${SUBJECT} | sed 's/URGENT //'`

    # Remove underscores from SUBJECT"

        SUBJECT=`echo ${SUBJECT} | sed 's/\_/ /g'`

    /usr/sbin/sendmail -t <<- EOM
	TO: ${TO_ADDRESS}
	FROM: ${FROM}
	SUBJECT: ${SUBJECT}
	MIME-Version: 1.0
	Importance: ${IMPORTANCE}
	${CONTENT_TYPE}
	
	${AMC_LINE1}
	${AMC_LINE2}
	${AMC_LINE3}
	
	<html>
	<head>
	<meta http-equiv="content-type" content="text/html; charset=ISO-8859-15">
	</head>
	<div align="left">
	<table width=100%>
	<tr>
		${CELL1}
		<td align='right'><font size=4 face=${INLINE_FONT} color=${COLOUR}><b>`date +'%a %e %b %R'`</b></font></td>
	</tr>
	</table>
	</div>
	<body bgcolor="${INLINE_COLOUR}" text="#000000">
     	<font size=1 face=${INLINE_FONT} color=${INLINE_FONT_COLOUR}>
   
        `if [[ "${INLINE_FILE}" == "null" ]]
        then
            echo "<td align='left'><font size=2 face=${INLINE_FONT} color=black>"Please see attached"<br></font></td>" 
        else
            echo "<pre>"
	    cat  ${INLINE_FILE} |
	    while read INLINE
	    do
	        echo "<td align='left'><font size=2 face=${INLINE_FONT} color=black>${INLINE}</font></td>" 
	    done  
            echo "</pre>"
        fi`
        </font>
	</body>
	</html>

	${AMC_LINE1A}
	${IMAGE_HTML1}
	${IMAGE_HTML2}
	${IMAGE_HTML3}
	${IMAGE_HTML4}
	
	${IMAGE_HTML5}

	${AMC_LINE1}
	${IMAGE_HTML6}
	${IMAGE_HTML7}
	${IMAGE_HTML8}

	${IMAGE_HTML9}
	EOM

#        rm -f ${ATTACH_FILE}
}

