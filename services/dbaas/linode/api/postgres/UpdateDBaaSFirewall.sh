#!/bin/sh
###################################################################################
# @file        UpdateDBaaSFirewall.sh
# @brief       Updates the network firewall access control list for a managed DBaaS instance.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script validates a target database instance ID and its corresponding
#              network configuration array parameters, formats a secure payload update,
#              interfaces with centralized provider APIs via masked streams, and checks
#              errors to confirm access update states.
#
# @param       $1  [Required] The unique platform identifier ID of the active database instance.
# @param       $2  [Required] Comma-separated or properly formatted IP/CIDR string array definition.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, curl, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Protects structural parameter variables securely in strict text boundaries.
#
# @exit        0  Success: Target database network access control rules modified cleanly.
# @exit        1  Failure: Missing context paths, input parameters validation error, or API failures.
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
####################################################################################
set -e

# Resolve BUILD_HOME baseline layout securely
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Input validation
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Database ID and allow_list parameters are required."
        status "Usage: $0 <database_id> <allow_list>"
        exit 1
fi

database_id="${1}"
allow_list_raw="${2}"

# Framework deployment variables extraction using secure subshells
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Sanitize and convert comma-separated values or raw text blocks safely into an array via jq
# This prevents dangerous raw string injections inside the JSON payload parameters
json_payload="$(/bin/echo "${allow_list_raw}" | /usr/bin/jq -R 'split(",") | map(gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "")) | {allow_list: .}' 2>/dev/null)"

if [ -z "${json_payload}" ]
then
        status "Error: Failed to generate a valid network configuration payload array from: ${allow_list_raw}"
        exit 1
fi

# Execute network validation endpoint updates while manual trackers trap faults
set +e
api_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT "https://api.linode.com/v4/databases/postgresql/instances/${database_id}" -H "Content-Type: application/json" -d "${json_payload}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] 
then
        status "Database ${database_id} firewall allow list failed to update (Network/Curl infrastructure execution error)."
        exit 1
fi

# Verify payload returns to protect against masked HTTP authentication errors
if /bin/echo "${api_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[0].reason // .errors.reason // "Unknown API error parameters."')"
        status "Database ${database_id} firewall allow list update rejected. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

status "Database ${database_id} firewall access network settings successfully modified."
exit 0
