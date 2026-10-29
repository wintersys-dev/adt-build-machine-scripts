#!/bin/sh
########################################################################################
# @file        IsInstanceRunning.sh
# @brief       Checks the current operational status of a Linode server by its name type.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script connects to the Linode v4 API, retrieves the instances
#              payload, and filters the list based on the provided server type keyword.
#              It returns the raw string status (e.g., "running", "stopped") of any
#              instance containing that substring within its label.
#
# @param       $1  [Required] The server type/name substring to search for in instance labels.
#
# @env         BUILD_HOME  Path to the framework root directory (read from file).
# @env         TOKEN       Linode API bearer authorization token.
#
# @exit        0  Success: The machine status was found and printed to stdout.
# @exit        1  Failure: Missing arguments, missing configuration, invalid token,
#                 network failure, or no server matched the specified criteria.
#
########################################################################################
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
########################################################################################
########################################################################################
#set -x
set -e

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

if ( [ "${1}" = "" ] )
then
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>"
        exit 1
fi

server_type="${1}"

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"

if [ ${TOKEN} != "" ] && response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s -H 'X-Filter: {"region": "'${REGION}'"}' "https://api.linode.com/v4/linode/instances")"
then
        output="$(echo "${response}" | jq -r --arg search "${server_type}" '.data[] | select(.label | contains($search)).status')"

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
