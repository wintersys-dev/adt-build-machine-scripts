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
# @env         BUILD_HOME          Path to the toolchain framework root directory.
# @env         TOKEN               Linode API bearer authorization token.
# @env         REGION              The region that the servers are running in.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - external dependencies: curl, jq, cat, mkdir, dirname, date, echo
#
# @security    
#              - Filters curl interactions through piped authorization headers via @- syntax.
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Wraps API data extractions safely in localized variables.
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
LOG_FILE="${BUILD_HOME}/runtime/logs/provisioning/ListServerIDs.log"

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
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>" 
        exit 1
fi

server_type="${1}"

# Secure framework configuration value extraction
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

if [ -z "${TOKEN}" ]
# Target routing token evaluation
then
        status "Error: API authorization TOKEN is empty or missing configuration."
        exit 1
fi

# Temporary disable set -e to evaluate curl transaction pipeline failures manually
set +e
response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s -H 'X-Filter: {"region": "'${REGION}'"}' "https://linode.com")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        output="$(/bin/echo "${response}" | /usr/bin/jq -r --arg search "${server_type}" '.data[] | select(.label | contains($search)).id')"

        if [ -z "${output}" ]
        then
                status "Error: No matching server instance found for server type ${server_type}."
                exit 1
        else
                /bin/echo "${output}"
        fi
else
        status "Network request failed. Check your API token or URL."
        exit 1
fi

exit 0
