#!/bin/sh
################################################################################
# @file        ListServerIDs.sh
# @brief       Lists all Linode instance IDs that match a given server type keyword.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script contacts the Linode v4 API, retrieves the list of active 
#              instances, and filters them using jq. It extracts the numerical 
#              ID for any instance whose label contains the specified server 
#              type keyword.
#
# @param       $1  [Required] The server type substring to find within instance labels.
#
# @env         BUILD_HOME  Path to the toolchain framework root directory.
# @env         TOKEN       Linode API bearer authorization token.
#
# @exit        0  Success: One or more matching IDs were found and printed to stdout.
# @exit        1  Failure: Missing arguments, missing configuration, invalid token, 
#                 network failure, or no labels matched the criteria.
################################################################################
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
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>" 
        exit 1
fi

server_type="${1}"

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"

if [ ${TOKEN} != "" ] && response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s "https://api.linode.com/v4/linode/instances")"
then
        output="$(echo "${response}" |  jq -r --arg search "${server_type}" '.data[] | select(.label | contains($search)).id')"

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
