#!/bin/sh
#################################################################################
# Author: Peter Winter
# Date  : 13/07/2016
# Description : This will create the DNS record for your current domain and is called
# at the end of building a webserver. Once this is called a webserver will have been
# added to the DNS system
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
####################################################################################
####################################################################################
set -x

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

record="${1}"
website_url="${2}" #The URL of the website
auth="${3}"
wireguard="${4}"


BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE`"
DNS_USERNAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME`"
DNS_SECURITY_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY`"
DNS_CHOICE="cloudflare"
MULTI_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh MULTI_REGION`"
PRIMARY_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh PRIMARY_REGION`"
AUTHENTICATOR_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTHENTICATOR_TYPE`"
LOAD_BALANCER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh LOAD_BALANCER`"

if ( [ "${website_url}" != "" ] )
then
        WEBSITE_URL="${website_url}"
else
        WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_URL`"
fi

if ( [ "${auth}" = "yes" ] )
then
        if ( [ "${wireguard}" != "yes" ] )
        then
                WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_SERVER_URL`"
        fi
        DNS_USERNAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_DNS_USERNAME`"
        DNS_SECURITY_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_DNS_SECURITY_KEY`"
fi

SERVER_USER="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials/SERVERUSER`"
SERVER_USER_PASSWORD="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials/SERVERUSERPASSWORD`"

if ( [ "${DNS_CHOICE}" != "" ] && ( [ "${LOAD_BALANCER}" = "0" ] || [ "${auth}" = "yes" ] ) )
then
        name="`/bin/echo ${WEBSITE_URL} | /usr/bin/awk -F'.' '{print $1}'`"
        zonename="`/bin/echo ${WEBSITE_URL} | /usr/bin/awk -F'.' '{$1=""}1' | /bin/sed 's/^ //g' | /bin/sed 's/ /./g'`"
        zoneid="`${BUILD_HOME}/services/dns/GetZoneID.sh "${zonename}" "${DNS_USERNAME}" "${DNS_SECURITY_KEY}" "${DNS_CHOICE}"`"

        if ( [ "${zoneid}" = "" ] )
        then
                ${BUILD_HOME}/services/dns/CreateZone.sh "${DNS_USERNAME}" "${DNS_SECURITY_KEY}" "${WEBSITE_URL}" "${DNS_CHOICE}"
                /bin/sleep 10
                zoneid="`${BUILD_HOME}/services/dns/GetZoneID.sh "${zonename}" "${DNS_USERNAME}" "${DNS_SECURITY_KEY}" "${DNS_CHOICE}"`"
        fi

        if ( [ "${MULTI_REGION}" = "0" ] || ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] ) )
        then 
                recordids="`${BUILD_HOME}/services/dns/GetAllRecordIDs.sh  "${zoneid}" "${WEBSITE_URL}" "${DNS_USERNAME}" "${DNS_SECURITY_KEY}" "${DNS_CHOICE}"`"

                if ( [ "${record}" = "primary" ] )
                then
                        if ( [ "${recordids}" != "" ] )
                        then
                                for recordid in ${recordids}
                                do
                                        ${BUILD_HOME}/services/dns/DeleteRecord.sh "${zoneid}" "${recordid}" "${DNS_USERNAME}" "${DNS_SECURITY_KEY}" "${DNS_CHOICE}" "${WEBSITE_URL}"
                                done
                        fi
                fi
        fi
fi
