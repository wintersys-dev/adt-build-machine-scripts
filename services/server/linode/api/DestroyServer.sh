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

BUILD_HOME="`/bin/cat /home/buildhome.dat`"


if ( [ "${1}" = "" ] )
then
    status "Error: Server ip argument is required."
    status "Usage: $0 <server_ip>" 
    exit 1
fi

server_ip="${1}"

TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

if [ "${server_ip}" != "" ]
then
    # 1. Lookup server ID by IP via API
    server_id="$(curl -s -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
        "https://api.linode.com/v4/linode/instances" | \
        jq -r '.data[] | select(.ipv4[] == "'${server_ip}'").id')"
    
  #  if [ "${server_id}" = "" ]
  #  then
  #      # Fallback script lookup
  #      server_ip="$(${BUILD_HOME}/services/server/GetServerPublicIPAddressByIP.sh ${server_ip})"
  #      
  #      # 2. Retry lookup with fallback IP via API
  #      server_id="$(curl -s -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
  #          "https://api.linode.com/v4/linode/instances" | \
  #          jq -r '.data[] | select(.ipv4[] == "'${server_ip}'").id')"
  #  fi
    
    if [ "${server_id}" != "" ]
    then
        # 3. API Shutdown command (POST /v4/linode/instances/{id}/shutdown)
        curl -s -X POST -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
            "https://api.linode.com/v4/linode/instances/${server_id}/shutdown" > /dev/null
            
# 2. Wait until the status changes to "offline"
while true; do
    status=$(curl -s -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
        "https://api.linode.com/v4/linode/instances/${server_id}" | jq -r '.status')
    
    if [ "$status" = "offline" ]; then
curl -s -X DELETE -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
    "https://api.linode.com/v4/linode/instances/${server_id}" > /dev/null
    fi
    sleep 5
done

# 3. Safe to delete now
curl -s -X DELETE -H "Authorization: Bearer $LINODE_CLI_TOKEN" \
    "https://api.linode.com/v4/linode/instances/${server_id}" > /dev/null
    fi
fi
