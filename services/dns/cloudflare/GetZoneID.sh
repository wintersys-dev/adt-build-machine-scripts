#!/bin/sh
#: Name:        GetZoneID.sh
#: Purpose:     Resolves the Cloudflare zone ID for a specified root domain zone name.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       GetZoneID.sh <zone_name>
#:              GetZoneID.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The apex root domain zone name (e.g. "example.com").
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/dns/cloudflare/<orchestration_tool>/get_zone_id.sh
#:   - External binaries: cat, echo, grep, cut, awk
#:
#: Exit Codes:
#:   0          Target Cloudflare zone ID successfully resolved and printed
#:   1          Missing context paths, input parameter errors, or API/CLI failures
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
#set -x
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

# Validate that the required target zone name argument was provided
if [ -z "${1}" ]
then
        status "Error: Zone name parameter is required."
        status "Usage: $0 <zone_name>"
        exit 1
fi

zone_name="${1}"

# Retrieve the active DNS provider choice from deployment context
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

if [ -z "${DNS_CHOICE}" ]
then
        status "Error: Failed to fetch required context variables (DNS_CHOICE)."
        exit 1
fi

# Read software.dat and resolve the active orchestration tool (cli or api)
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

if [ ! -d "${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

# Query the Cloudflare zone ID via the active orchestration wrapper
set +e
zone_id="$("${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/get_zone_id.sh" "${zone_name}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${zone_id}" ]
then
        status "Failed to get zone id for zone ${zone_name} (Network/Curl connection error)."
        exit 1
fi

/bin/echo "${zone_id}"
exit 0

