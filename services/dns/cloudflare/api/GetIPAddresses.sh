#!/bin/sh
######################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : Get the ip addresses for a given website_url from the DNS system
######################################################################################
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
#######################################################################################
#######################################################################################
#set -x

set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

website_url="${1}"

DNS_USERNAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME`"
DNS_SECURITY_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY`"
DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE`"

zone_name="`/bin/echo ${website_url} | /usr/bin/cut -d'.' -f2-`"
zone_id="`${BUILD_HOME}/services/dns/GetZoneID.sh "${zone_name}"`"

if ( [ "${zone_id}" = "" ] )
then
        ${BUILD_HOME}/services/dns/CreateZone.sh  "${website_url}"
        zone_id="`${BUILD_HOME}/services/dns/GetZoneID.sh "${zone_name}"`"
fi

if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
then
        api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
        /bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${website_url}"  -H "Content-Type: application/json" | /usr/bin/jq -r '.result[].content'
else
        /bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${website_url}"  -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json" | /usr/bin/jq -r '.result[].content'
fi

if ( [ "$?" != "0" ] )
then
        status "Failed to get IP addresses for domain ${website_url}"
        exit 1
fi
