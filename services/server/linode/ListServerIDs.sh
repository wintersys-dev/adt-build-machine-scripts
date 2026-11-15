#!/bin/sh
#: Name:        ListServerIDs.sh
#: Purpose:     Lists all Linode instance IDs that match a given server type keyword.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       ListServerIDs.sh <server_type>
#:              ListServerIDs.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The server type substring to find within instance labels.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/server/linode/<orchestration_tool>/list_instances.sh
#:   - External binaries: cat, echo, grep, cut, awk, tr, jq
#:
#: Exit Codes:
#:   0          One or more matching instance IDs were found and printed to stdout
#:   1          Missing arguments, invalid config, network failure, or no matching labels
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
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

# Exit immediately if any command exits with a non-zero status
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the system tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Validate that the required server type argument was provided
if [ -z "${1}" ]
then
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>"
        exit 1
fi

server_type="${1}"

# Retrieve authentication token and target region from active deployment context
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

# Read software.dat and resolve the active orchestration tool (cli or api)
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

if [ ! -d "${BUILD_HOME}/services/server/linode/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

# Query active Linode instances in the target region via the orchestration wrapper
set +e
response="$("${BUILD_HOME}/services/server/linode/${orchestration_tool}/list_instances.sh" "${REGION}")"
curl_status="$?"
set -e

# Filter the instance catalog (supporting both API .data[] and CLI .[] shapes) for matching labels
if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        output="$(/bin/echo "${response}" | /usr/bin/jq -r --arg search "${server_type}" '(if type == "object" and has("data") then .data else . end)[] | select(.label | contains($search)).id // empty')"

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

