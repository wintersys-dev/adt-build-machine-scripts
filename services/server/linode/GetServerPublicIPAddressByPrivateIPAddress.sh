#!/bin/sh
#: Name:        GetServerPublicIPAddressByPrivateIPAddress.sh
#: Purpose:     Resolves a machine's public NAT IP based on its private VPC IP.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       GetServerPublicIPAddressByPrivateIPAddress.sh <private_ip>
#:              GetServerPublicIPAddressByPrivateIPAddress.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The target private VPC IPv4 address to translate.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/server/linode/<orchestration_tool>/get_vpc_ips.sh
#:   - External binaries: cat, echo, grep, cut, awk, tr, jq
#:
#: Exit Codes:
#:   0          Public NAT IP was found and printed to stdout
#:   1          Missing arguments, invalid config, network failure, or no 1:1 NAT mapping
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

# Validate that the required target private IP address argument was provided
if [ -z "${1}" ]
then
        status "Error: Server ip argument is required."
        status "Usage: $0 <server_ip>"
        exit 1
fi

server_ip="${1}"

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

# Query regional VPC IP assignments via the active orchestration wrapper
set +e
response="$("${BUILD_HOME}/services/server/linode/${orchestration_tool}/get_vpc_ips.sh" "${REGION}")"
curl_status="$?"
set -e

# Extract the 1:1 NAT public IPv4 mapped to the target private VPC IP (supporting both API .data[] and CLI .[] shapes)
if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        output="$(/bin/echo "${response}" | /usr/bin/jq -r --arg ip "${server_ip}" '(if type == "object" and has("data") then .data else . end)[] | select(.address == $ip).nat_1_1 // empty')"

        # Ensure a valid non-null NAT string was returned before printing
        if [ -z "${output}" ] || [ "${output}" = "null" ]
        then
                status "Error: No matching public IP address found for server ip ${server_ip}."
                exit 1
        else
                /bin/echo "${output}"
        fi
else
        status "Network request failed. Check your API token or URL."
        exit 1
fi

exit 0

