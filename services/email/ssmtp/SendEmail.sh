#!/bin/sh
################################################################################
# Description: Send emails using ssmtp
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

HOME="`/bin/cat /home/homedir.dat`"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] )
then
        status "Error: Minimum of 3 arguments required."
        status "Usage: $0 <subject> <message> <to_address>"
        exit 1
fi

subject="$1"
message="$2"
to_address="$3"
content_type="$4"

EMAIL_PROVIDER="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILPROVIDER'`"
FROM_ADDRESS="`${HOME}/utilities/config/ExtractConfigValue.sh 'SYSTEMFROMEMAILADDRESS'`"
FROM_NAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEDISPLAYNAME | /usr/bin/sed 's/_//g''`"
TO_ADDRESS="`${HOME}/utilities/config/ExtractConfigValue.sh 'SYSTEMTOEMAILADDRESS'`"
USERNAME="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILUSERNAME'`"
PASSWORD="`${HOME}/utilities/config/ExtractConfigValue.sh 'EMAILPASSWORD'`"


if ( [ "${to_address}" != "system" ] )
then
        TO_ADDRESS="${to_address}"
fi

if ( [ "${content_type}" = "default" ] )
then
        content_type=""
fi

if ( [ ! -f ${HOME}/runtime/SSMTP_INITIALISED ] )
then
        if ( [ "${EMAIL_PROVIDER}" = "1" ] )
        then
                /bin/echo "mailhub=smtp-pulse.com:2525" >> /etc/ssmtp/ssmtp.conf
        fi
        if ( [ "${EMAIL_PROVIDER}" = "2" ] )
        then
                /bin/echo "mailhub=in-v3.mailjet.com:587" >> /etc/ssmtp/ssmtp.conf
        fi
        if ( [ "${EMAIL_PROVIDER}" = "3" ] )
        then
                /bin/echo "mailhub=email-smtp.eu-west-1.amazonaws.com" >> /etc/ssmtp/ssmtp.conf
        fi

        /bin/echo "AuthUser=${USERNAME}" >> /etc/ssmtp/ssmtp.conf
        /bin/echo "AuthPass=${PASSWORD}" >> /etc/ssmtp/ssmtp.conf
        /bin/echo "FromLineOverride=YES" >> /etc/ssmtp/ssmtp.conf
        /bin/echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf
        /bin/touch ${HOME}/runtime/SSMTP_INITIALISED
fi

if ( [ "${content_type}" = "HTML" ] )
then
        /bin/echo "${message}" | /usr/bin/mail -s "${subject}" -a "From: ${FROM_NAME} <${FROM_ADDRESS}>" "${TO_ADDRESS}" -a 'Content-Type: text/html'
else
        /bin/echo "${message}" | /usr/bin/mail -s "${subject}" -a "From: ${FROM_NAME} <${FROM_ADDRESS}>" "${TO_ADDRESS}"
fi

if ( [ "$?" != "0" ] )
then
        /bin/echo "Failed to send email"
        exit 1
fi
