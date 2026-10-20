#!/bin/sh
################################################################################
# Description: This script is using for sending emails based on whatever email utility
# is configured for use in software.dat
# Date: 16-11-2016
# Author: Peter Winter
##################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#####################################################################################
#####################################################################################
#set -x
set -e

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] )
then
        status "Error: Minimum of 3 arguments required."
        status "Usage: $0 <subject> <message> <level>"
        exit 1
fi

subject="$1"
message="$2"
level="$3"
to_address="$4"
authentication="${5}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( ( [ "${level}" = "ERROR" ] || [ "${level}" = "INFO" ] || [ "${level}" = "MANDATORY" ] ) && [ "${authentication}" != "AUTHENTICATION" ] )
then
        ip_address="`${BUILD_HOME}/helpers/services/GetBuildMachineIP.sh`"
        message="MESSAGE RELATED TO MACHINE WITH IP ADDRESS: ${ip_address}: ${message}"
fi

email_util="`/bin/grep "^EMAILUTIL:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $NF}'`"

if ( [ "${level}" != "MANDATORY" ] && [ "`${BUILD_HOME}/helpers/services/GetVariableValue.sh EMAIL_NOTIFICATION_LEVEL`" = "ERROR" ] && [ "${level}" != "ERROR" ] )
then
        exit
fi

if ( [ "${to_address}" = "" ] )
then
        to_address="system"
fi

if ( [ "${content_type}" = "" ] )
then
        content_type="default"
fi

${BUILD_HOME}/services/email/${email_util}/SendEmail.sh "${subject}" "${message}" "${to_address}" "${content_type}"

if ( [ "$?" != "0" ] )
then
        status "SendEmail.sh failed to send email"
        exit 1
fi
