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
# @env         BUILD_HOME          Path to the framework root directory (read from file).
# @env         TOKEN               Linode API bearer authorization token.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - GetServerName.sh helper resolution tool tracking instance labels by IP.
#              - ListServerIDs.sh helper resolution tool translating instance labels into IDs.
#              - external dependencies: curl, jq, expr, sleep, cat, mkdir, dirname, date
#
# @security    
#              - Filters curl interactions through piped authorization headers via @- syntax.
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Wraps API data extractions safely in localized variables.
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
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
###################################################################################
###################################################################################
#set -x
set -e

# Resolve BUILD_HOME baseline layout securely
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

if [ ! -d ${BUILD_HOME}/runtime/logs/provisioning ]
then
        /bin/mkdir -p ${BUILD_HOME}/runtime/logs/provisioning
fi

# Define log file destination path
LOG_FILE="${BUILD_HOME}/runtime/logs/provisioning/DestroyServer.log"

# Unified status wrapper mimicking the original behavior and appending to log streams safely
status()
{
        # Execute the original framework status tool safely
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
        
        # Mirror output to dedicated runtime log if target directory is writable
        status_msg="[$(/bin/date '+%Y-%m-%d %H:%M:%S')] STATUS: ${1}"
        if [ -w "${LOG_FILE}" ] || [ -w "$(/usr/bin/dirname "${LOG_FILE}")" ]
        then
                /bin/echo "${status_msg}" >> "${LOG_FILE}"
        fi
}

# Input validation
if [ -z "${1}" ]
then
        status "Error: Server ip argument is required."
        status "Usage: $0 <server_ip>" 
        exit 1
fi

server_ip="${1}"

# Secure framework configuration value extraction
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Map out structural infrastructure identifiers
server_name="$("${BUILD_HOME}/services/server/linode/api/GetServerName.sh" "${server_ip}")"

if [ -n "${server_name}" ] 
then
        server_id="$("${BUILD_HOME}/services/server/linode/api/ListServerIDs.sh" "${server_name}")"
        
        status "Initiating graceful shutdown for instance '${server_name}' (ID: ${server_id}, IP: ${server_ip})..."
        
        # Dispatch shutdown request securely
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -f -X POST "https://api.linode.com/v4/linode/instances/${server_id}/shutdown" > /dev/null

        count="0"
        while true
        do
                # Fetch target runtime instance environment state tracking flags safely
                current_status="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://linode.com{server_id}" | /usr/bin/jq -r '.status')"
                
                if [ "${current_status}" = "offline" ] || [ "${count}" -ge 21 ]
                then
                        break
                fi

                status "Waiting for machine with id: ${server_id} and ip address ${server_ip} to be offline following a shutdown request"
                /bin/sleep 10
                count="$(/usr/bin/expr "${count}" + 1)"
        done

        status "Executing permanent deletion routine for instance ID: ${server_id}..."
        
        # Dispatch final removal payload transaction securely
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -f -X DELETE "https://linode.com{server_id}" > /dev/null
        
        status "Machine with id: ${server_id} and ip address ${server_ip} has been deleted"
else
        status "Error: No active server instance records matched IP tracking descriptor '${server_ip}'."
        exit 1
fi

exit 0
