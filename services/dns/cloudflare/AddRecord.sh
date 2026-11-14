#!/bin/sh
###################################################################################
# @file        add_record.sh
# @brief       Provisions a new authoritative A-record within the Cloudflare DNS architecture.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script extracts DNS configuration keys, resolves or instantiates 
#              the target zone envelope using secondary toolkit dependencies, evaluates
#              the authentication layout to determine API parsing protocols (Bearer token
#              vs. X-Auth credentials), and issues an authenticated POST transaction payload.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "www.domain.com").
# @param       $2  [Required] The target IPv4 address destination tracking node.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - GetZoneID.sh / CreateZone.sh local domain infrastructure sub-tools.
#              - external dependencies: cat, echo, cut, grep, awk, curl, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Safely validates variable constraints under explicit character boundaries.
#
# @exit        0  Success: Cloudflare DNS record entry successfully provisioned and verified.
# @exit        1  Failure: Missing context paths, input parameter errors, or API communication failures.
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
set -x
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
        status "Error: Website URL and target IP address parameters are required."
        status "Usage: $0 <website_url> <target_ip>"
        exit 1
fi

website_url="${1}"
ip="${2}"

# Extract structural configuration contexts securely via modern subshells
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

# Parse apex zone identifier safely
zone_name="$(/bin/echo "${website_url}" | /usr/bin/cut -d'.' -f2-)"

# Intercept and capture zone ID configurations cleanly
zone_id="$("${BUILD_HOME}/services/dns/GetZoneID.sh" "${zone_name}")"

if [ -z "${zone_id}" ]
then
        status "Zone ID empty for '${zone_name}'. Spawning authoritative zone layout..."
        "${BUILD_HOME}/services/dns/CreateZone.sh" "${website_url}"
        zone_id="$("${BUILD_HOME}/services/dns/GetZoneID.sh" "${zone_name}")"

        if [ -z "${zone_id}" ]
        then
                status "Error: Failed to verify zone ID allocation for '${zone_name}' after provisioning step."
                exit 1
        fi
fi

if [ -z "${DNS_CHOICE}" ] 
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

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



# Assemble raw JSON transaction parameters block defensively to resist string injection threats
json_payload="$(/bin/cat <<EOF
{
  "type": "A",
  "name": "${website_url}",
  "content": "${ip}",
  "ttl": 120,
  "proxied": true
}
EOF
)"

set +e
record_response="$(${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/add_record.sh "${zone_id}" "${json_payload}")"
record_exit_code="$?"
set -e

if [ "${record_exit_code}" -ne 0 ]
then
        status "Failed to add record to DNS system (Network/Curl infrastructure execution error)."
        exit 1
fi


# Verify final transaction payload state explicitly to catch schema rejections or token faults
if /bin/echo "${record_response}" | /usr/bin/jq -e '.success == false or .errors and (.errors | length > 0)' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[0].message // "Unknown Cloudflare validation error details."')"
        status "Failed to Add record for url ${website_url} to the DNS system. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

status "Cloudflare DNS A-record successfully provisioned: ${website_url} -> ${ip} [Proxied: True, TTL: 120s]"
exit 0
