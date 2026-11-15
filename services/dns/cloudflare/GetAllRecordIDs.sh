#!/bin/sh
#: Name:        GetAllRecordIDs.sh
#: Purpose:     Resolves unique Cloudflare DNS record identifiers for a targeted URL.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       GetAllRecordIDs.sh <website_url>
#:              GetAllRecordIDs.sh [-h|--help]
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
#:   - GetZoneID.sh / CreateZone.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/dns/cloudflare/<orchestration_tool>/get_all_record_ids.sh
#:   - External binaries: cat, echo, cut, grep, awk
#:
#: Exit Codes:
#:   0          Target DNS record IDs successfully resolved and printed
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

# Validate that the required website URL argument was provided
if [ -z "${1}" ]
then
        status "Error: Website URL parameter is required."
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
# Look up the Cloudflare zone ID, creating the authoritative zone if it does not yet exist
set +e
zone_id="$("${BUILD_HOME}/services/dns/GetZoneID.sh" "${zone_name}")"
set -e

if [ -z "${zone_id}" ]
then
        status "Zone ID empty for '${zone_name}'. Spawning authoritative zone layout..."
        "${BUILD_HOME}/services/dns/CreateZone.sh" "${website_url}"
        set +e
        zone_id="$("${BUILD_HOME}/services/dns/GetZoneID.sh" "${zone_name}")"
        set -e
        
        if [ -z "${zone_id}" ]
        then
                status "Error: Failed to verify zone ID allocation for '${zone_name}' after provisioning step."
                exit 1
        fi
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

# Query Cloudflare record IDs matching the website URL within the resolved zone
set +e
record_ids="$("${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/get_all_record_ids.sh" "${website_url}" "${zone_id}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${record_ids}" ]
then
        status "Failed to get record IDs for domain ${website_url} (Network/Curl infrastructure execution error)."
        exit 1
fi

/bin/echo "${record_ids}"
exit 0

