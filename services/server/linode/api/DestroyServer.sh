#!/bin/sh
###################################################################################
# @file        DestroyServer.sh
# @brief       Gracefully shuts down and permanently deletes a Linode server by IP.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script orchestrates the destruction of a specific Linode instance.
#              It resolves the instance ID via its IPv4 address, issues a shutdown 
#              POST request, polls the API up to 21 times (3.5 minutes) waiting for 
#              an 'offline' status, and finally executes a permanent DELETE request.
#
# @param       $1  [Required] The target IPv4 address of the instance to destroy.
#
# @env         BUILD_HOME  Path to the framework root directory (read from file).
# @env         TOKEN       Linode API bearer authorization token.
#
# @exit        0  Success: The instance was successfully shut down and deleted.
# @exit        1  Failure: Missing arguments, missing configuration, api communication 
#                 errors, or failure during the deletion sequence.
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
set -e

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
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
server_name="$(${BUILD_HOME}/services/server/linode/api/GetServerName.sh ${server_ip})"

if [ "${server_name}" != "" ] 
then
        server_id="$(${BUILD_HOME}/services/server/linode/api/ListServerIDs.sh ${server_name})"
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s  -X POST  "https://api.linode.com/v4/linode/instances/${server_id}/shutdown" > /dev/null
        if ( [ "$?" != "0" ] )
        then
                exit 1
        fi

        count="0"
        while ( [ "`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/linode/instances/${server_id}" | jq -r '.status'`" != "offline" ] && [ "${count}" -lt "21" ] )
        do
                status "Waiting for machine with id: ${server_id} and ip address ${server_ip} to be offline following a shutdown request"
                /bin/sleep 10
                count="`/usr/bin/expr ${count} + 1`"
        done

        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X DELETE "https://api.linode.com/v4/linode/instances/${server_id}" > /dev/null

        if ( [ "$?" != "0" ] )
        then
                exit 1
        else
                status "Machine with id: ${server_id} and ip address ${server_ip} has been deleted"
        fi
fi
