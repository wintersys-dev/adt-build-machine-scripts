#!/bin/sh
#: Name:        GetServerPrivateIPAddresses.sh
#: Purpose:     Retrieves the private VPC IPv4 addresses for a given server type.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       GetServerPrivateIPAddresses.sh <server_type>
#:              GetServerPrivateIPAddresses.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The server type/name substring used to resolve server IDs.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ListServerIDs.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/server/linode/<orchestration_tool>/list_instances.sh
#:   - ${BUILD_HOME}/services/server/linode/<orchestration_tool>/get_instance_ips.sh
#:   - External binaries: cat, echo, grep, cut, awk, tr, jq
#:
#: Exit Codes:
#:   0          One or more private VPC IP addresses were resolved and printed
#:   1          Missing arguments, invalid config, network failure, or no VPC IPs found
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

# Retrieve target cloud region from active deployment context
set +e
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"
set -e

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

# Resolve all matching Linode server IDs for the requested server type
server_ids="$("${BUILD_HOME}/services/server/linode/ListServerIDs.sh" "${server_type}")"

# Verify that the regional instance catalog is reachable before querying per-ID IPs
set +e
response="$("${BUILD_HOME}/services/server/linode/${orchestration_tool}/list_instances.sh" "${REGION}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        # Iterate through each matching server ID and extract its private VPC IPv4 addresses
        for id in ${server_ids}
        do
                set +e
                response1="$("${BUILD_HOME}/services/server/linode/${orchestration_tool}/get_instance_ips.sh" "${id}")"
                curl_sub_status="$?"
                set -e

                if [ "${curl_sub_status}" -eq 0 ] && [ -n "${response1}" ]
                then
                        # Support both API object ({...}) and CLI array ([{...}]) JSON shapes
                        output="$(/bin/echo "${response1}" | /usr/bin/jq -r '(if type == "array" then first else . end) | .ipv4.vpc[]?.address // empty')"

                        if [ -z "${output}" ]
                        then
                                status "Error: No matching private ip address found for server id ${id}."
                                exit 1
                        else
                                /bin/echo "${output}"
                        fi
                else
                        status "Error: Network request failed when querying IPs for server ID ${id}."
                        exit 1
                fi
        done
else
        status "Network request failed. Check your API token or URL."
        exit 1
fi

exit 0

