#!/bin/sh
#: Name:        CreateZone.sh
#: Purpose:     Provisions a new authoritative DNS zone within the Cloudflare DNS architecture.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       CreateZone.sh <website_url>
#:              CreateZone.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The target Fully Qualified Domain Name (e.g. "://example.com").
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/dns/cloudflare/<orchestration_tool>/create_zone.sh
#:   - External binaries: cat, echo, cut, grep, awk, jq
#:
#: Exit Codes:
#:   0          Cloudflare DNS zone successfully provisioned and verified
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
set -x
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

# Validate that the required website URL argument was provided
if [ -z "${1}" ]
then
        status "Error: Website URL address parameter is required."
        status "Usage: $0 <website_url>"
        exit 1
fi

website_url="${1}"

# Retrieve the active DNS provider choice from deployment context
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

if [ -z "${DNS_CHOICE}" ]
then
        status "Error: Failed to fetch required context variables (DNS_CHOICE)."
        exit 1
fi

# Isolate the apex root zone domain from the FQDN
zone_name="$(/bin/echo "${website_url}" | /usr/bin/cut -d'.' -f2-)"
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

# Dispatch the zone creation request to the active Cloudflare orchestration wrapper
set +e
response="$("${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/create_zone.sh" "${zone_name}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Failed to create zone in DNS system (Network/Curl infrastructure execution error)."
        exit 1
fi

# Verify that Cloudflare reported success and did not return validation or token errors
if /bin/echo "${response}" | /usr/bin/jq -e '.success == false or .errors and (.errors | length > 0)' >/dev/null 2>&1
then
        err_msg="$(/bin/echo "${response}" | /usr/bin/jq -r '.errors[0].message // "Unknown Cloudflare validation error details."')"
        status "Failed to create zone associated with url ${website_url} in the DNS system. Cloud Provider Reason: ${err_msg}"
        exit 1
fi

status "Cloudflare DNS zone successfully provisioned: ${zone_name}"
exit 0

