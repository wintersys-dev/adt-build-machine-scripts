#!/bin/sh
###################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will destroy the specified server by ip address
###################################################################################
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
###################################################################################
###################################################################################
#set -x
#set -e

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

if ( [ "${1}" = "" ] )
then
        status "Error: Server ip argument is required."
        status "Usage: $0 <server_ip>" 
        exit 1
fi

server_ip="${1}"

if ( [ "${server_ip}" != "" ] )
then
        server_id="`curl -s -H "Authorization: Bearer $TOKEN" "https://api.linode.com/v4/linode/instances" | jq -r '.data[] | select(.ipv4[] == "'${server_ip}'").id')`"
        if ( [ "${server_id}" = "" ] )
        then
                server_ip="`${BUILD_HOME}/services/server/GetServerPublicIPAddressByIP.sh ${server_ip}`"
                server_id="`curl -s -H "Authorization: Bearer $TOKEN" "https://api.linode.com/v4/linode/instances" | jq -r '.data[] | select(.ipv4[] == "'${server_ip}'").id')`"
        fi

        curl -s -X POST -H "Authorization: Bearer $TOKEN"  "https://api.linode.com/v4/linode/instances/${server_id}/shutdown" > /dev/null

        if ( [ "$?" != "0" ] )
        then
                exit 1
        fi

        count="0"
        while ( [ "`curl -s -H "Authorization: Bearer $TOKEN" "https://api.linode.com/v4/linode/instances/${server_id}" | jq -r '.status'`" != "offline" ] && [ "${count}" -lt "21" ] )
        do
                status "Waiting for machine with id: ${server_id} and ip address ${server_ip} to be offline following a shutdown request"
                /bin/sleep 10
                count="`/usr/bin/expr ${count} + 1`"
        done

        curl -s -X DELETE -H "Authorization: Bearer $TOKEN" "https://api.linode.com/v4/linode/instances/${server_id}" > /dev/null

        if ( [ "$?" != "0" ] )
        then
                exit 1
        else
                status "Waiting for machine with id: ${server_id} and ip address ${server_ip} has been deleted"
        fi
fi
