#!/bin/sh
#####################################################################################
# @file        GetServerName.sh
# @brief       Retrieves the Linode server label associated with a specific IP address.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script connects to the Linode v4 API, fetches the active instance 
#              catalog, and filters the JSON payload to match the provided IPv4 
#              argument. It requires a valid token configuration from the Agile 
#              Deployment Toolkit framework.
#
# @param       $1  [Required] The target IPv4 address of the server instance.
#
# @env         BUILD_HOME  Path to the framework root directory (read from file).
# @env         TOKEN       Linode API bearer authorization token.
# @env         REGION      The region that the servers are running in
#
# @exit        0  Success: The server label was found and printed to stdout.
# @exit        1  Failure: Missing arguments, missing configuration, invalid token, 
#                 network timeouts, or no server matched the specified IP address.
#
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

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

if ( [ "${1}" = "" ] )
then
        status "Error: Server ip argument is required."
        status "Usage: $0 <server_ip>" 
        exit 1
fi

server_ip="${1}"
TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

if [ ${TOKEN} != "" ] && response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s -H 'X-Filter: {"region": "'${REGION}'"}'  "https://api.linode.com/v4/linode/instances")" 
then
        output="$(echo "${response}" | jq -r --arg ip "${server_ip}" '.data[] | select(.ipv4[] == $ip).label')"

        if [ "${output}" = "" ]
        then
                status "Error: No matching server instance found for IP ${server_ip}."
                exit 1
        else
                echo "${output}"
        fi
else
        status "Network request failed. Check your API token or URL." 
        exit 1
fi
