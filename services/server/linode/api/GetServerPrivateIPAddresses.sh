#!/bin/sh
#########################################################################################
# @file        GetServerPrivateIPAddresses.sh
# @brief       Retrieves the private VPC IPv4 addresses for a given server type.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script queries the local toolkit environment to identify target 
#              server IDs matching a specific type string. It then loops through each 
#              ID, hits the Linode v4 IPs endpoint, and extracts the associated 
#              private VPC address fields using jq filtering.
#
# @param       $1  [Required] The server type/name substring used to resolve server IDs.
#
# @env         BUILD_HOME  Path to the framework root directory (read from file).
# @env         TOKEN       Linode API bearer authorization token.
# @env         REGION      The region that the servers are running in
#
# @exit        0  Success: One or more private IP addresses were resolved and printed.
# @exit        1  Failure: Missing arguments, invalid token, network timeouts, or 
#                 no valid VPC IP assignments were found for the matching servers.
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
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

server_ids="$(${BUILD_HOME}/services/server/linode/api/ListServerIDs.sh ${server_type})"

if [ ${TOKEN} != "" ] && response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s -H 'X-Filter: {"region": "'${REGION}'"}' "https://api.linode.com/v4/linode/instances")"
then
        if [ "${response}" = "" ]
        then
                status "Error: No matching server instance found for server type ${server_type}."
                exit 1
        else
                for id in ${server_ids}
                do
                        if [ ${TOKEN} != "" ] && response1="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s "https://api.linode.com/v4/linode/instances/${id}/ips")"
                        then
                                output="$(echo "${response1}" | jq -r '.ipv4.vpc[] | .address')"

                                if [ "${output}" = "" ]
                                then
                                        status "Error: No matching private ip address found for server id ${id}."
                                        exit 1
                                else
                                        echo "${output}"
                                fi
                        fi
                done
        fi
else
        status "Network request failed. Check your API token or URL."
        exit 1
fi
