#!/bin/sh
############################################################################################
# @file        NumberOfServers.sh
# @brief       Counts the number of active Linode servers containing a specific type string.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script queries the Linode v4 API to fetch all active instances, 
#              then parses the JSON response using jq to determine how many server 
#              labels match or contain the provided 'server_type' substring. It acts 
#              as an integrated module within the Agile Deployment Toolkit.
#
# @param       $1  [Required] The server type substring to search for within instance labels.
#
# @env         BUILD_HOME  Path to the core toolchain root directory (read from file).
# @env         TOKEN       Linode API bearer authorization token.
# @env         REGION      The region that the servers are running in
#
# @exit        0  Success: A count was calculated and printed to stdout.
# @exit        1  Failure: Missing arguments, missing configurations, invalid token, 
#                 network timeouts, or API payload execution issues.
############################################################################################
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
##########################################################################################
##########################################################################################
#set -x
set -e

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

if [ "${1}" = "" ]
then
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>" 
        exit 1
fi

server_type="${1}"

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

if [ ${TOKEN} != "" ] && response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s -H 'X-Filter: {"region": "'${REGION}'"}' "https://api.linode.com/v4/linode/instances")" 
then
        output="$(echo "${response}" | jq --arg search "${server_type}" '[.data[] | select(.label | contains($search))] | length')"

        if [ "${output}" = "" ]
        then
                status "Error: No matching server instance found for server type ${server_type}."
                exit 1
        else
                echo "${output}"
        fi
else
        status "Network request failed. Check your API token or URL." 
        exit 1
fi


