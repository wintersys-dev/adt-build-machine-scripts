#!/bin/sh
############################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This scripts lists the number of servers of a particular type that are running
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

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] )
then
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>" 
        exit 1
fi

server_type="${1}"

TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

#/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/linode/instances" |  jq '[.data[] | select(.label | contains("'${server_type}'"))] | length'

# 1. Pipe the sensitive token configuration securely into curl's stdin
response=$(/bin/echo 'header = "Authorization: Bearer '${TOKEN}'"' | curl -m 10 -f -s -K - "https://api.linode.com/v4/linode/instances")

# 2. Capture the exact exit status of the curl operation
curl_exit=$?

# 3. Check for failures (network drops, timeouts, 404, 500)
if [ "$curl_exit" -ne 0 ]; then
    echo "Linode API request failed (Exit code: $curl_exit)"
    exit 1
fi

# 4. Safely inject the variable as a string argument into jq
echo "$response" | jq --arg search "$server_type" '[.data[] | select(.label | contains($search))] | length'


