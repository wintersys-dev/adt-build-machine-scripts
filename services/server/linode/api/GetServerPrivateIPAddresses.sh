#!/bin/sh
#########################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description :  This script gets the private ip address of a machine given its unique name
#########################################################################################
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

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] )
then
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>" 
        exit 1
fi

server_type="${1}"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
server_ids="$(${BUILD_HOME}/services/server/linode/api/ListServerIDs.sh ${server_type})"

if [ ${TOKEN} != "" ] && response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s "https://api.linode.com/v4/linode/instances")"
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
                                        status "Error: No matching server instance found for server type ${server_type}."
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
