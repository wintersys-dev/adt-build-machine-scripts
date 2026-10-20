#!/bin/sh
################################################################################
# Description: Send emails using sendemail
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

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] )
then
        /bin/echo "Error: 3 arguments are required."
        /bin/echo "Usage: $0 <subject> <message> <to_address>"
        exit 1
fi

subject="$1"
message="$2"
to_address="$3"

EMAIL_PROVIDER="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILPROVIDER'`"
FROM_ADDRESS="`${HOME}/utilities/config/ExtractConfigValue.sh 'SYSTEMFROMEMAILADDRESS'`"
TO_ADDRESS="`${HOME}/utilities/config/ExtractConfigValue.sh 'SYSTEMTOEMAILADDRESS'`"
USERNAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILUSERNAME'`"
PASSWORD="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILPASSWORD'`"

if ( [ "${to_address}" != "system" ] )
then
        TO_ADDRESS="${to_address}"
fi

if ( [ "${EMAIL_PROVIDER}" = "1" ] )
then
        /usr/bin/sendemail -o tls=no -f ${FROM_ADDRESS} -t ${TO_ADDRESS} -s smtp-pulse.com:2525 -xu ${USERNAME} -xp ${PASSWORD} -u "${subject} `/bin/date`" -m "${message}"
fi

if ( [ "${EMAIL_PROVIDER}" = "2" ] )
then
        /usr/bin/sendemail -o tls=no -f ${FROM_ADDRESS} -t ${TO_ADDRESS} -s in.mailjet.com:2525 -xu ${USERNAME} -xp ${PASSWORD} -u "${subject} `/bin/date`" -m "${message}"            
fi

if ( [ "${EMAIL_PROVIDER}" = "3" ] )
then
        /usr/bin/sendemail -o tls=no -f ${FROM_ADDRESS} -t ${TO_ADDRESS} -s email-smtp.eu-west-1.amazonaws.com -xu ${USERNAME} -xp ${PASSWORD} -u "${subject} `/bin/date`" -m "${message}"
fi

if ( [ "$?" != "0" ] )
then
	/bin/echo "Failed to send email"
	exit 1
fi
	
