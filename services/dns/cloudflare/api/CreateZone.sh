#!/bin/sh
######################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : Given a zone name if the zone doesn't exist the API is used to create it
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

zone_name="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DNS_USERNAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME`"
DNS_SECURITY_KEY="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY`"

if ( [ "`curl -s -X GET ""https://api.cloudflare.com/client/v4/zones?name=${zone_name}""  -H "X-Auth-Email: ${DNS_USERNAME}"  -H "X-Auth-Key: ${DNS_SECURITY_KEY}" -H "Content-Type: application/json" | /usr/bin/jq -r 'if (.result | length) > 0 then "true" else "false" end'`" = "false" ] )
then
        if ( [ "`/bin/echo ${DNS_SECURITY_KEY} | /bin/grep ':::'`" != "" ] )
        then
                api_token="`/bin/echo ${DNS_SECURITY_KEY} | /usr/bin/awk -F':::' '{print $2}'`"
                /usr/bin/curl -X POST "https://api.cloudflare.com/client/v4/zones" --header "Authorization: Bearer ${api_token}" --header "Content-Type: application/json" --data '{"name":"'${zone_name}'"}' 
        else
                /usr/bin/curl -X POST "https://api.cloudflare.com/client/v4/zones" -H "X-Auth-Email: ${DNS_USERNAME}" -H "X-Auth-Key: ${DNS_SECURITY_KEY}" -H "Content-Type: application/json" --data '{"name":"'${zone_name}'"}'
        fi

        while ( [ "`curl -s -X GET ""https://api.cloudflare.com/client/v4/zones?name=${zone_name}""  -H "X-Auth-Email: ${DNS_USERNAME}"  -H "X-Auth-Key: ${DNS_SECURITY_KEY}" -H "Content-Type: application/json" | /usr/bin/jq -r 'if (.result | length) > 0 then "true" else "false" end'`" = "false" ] )
        do
                /bin/sleep 5
        done
fi
