#!/bin/sh
#: Name:        AddRecord.sh
#: Purpose:     Provisions a new dynamic A-record entry within the Linode DNS provider matrix.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       AddRecord.sh <fqdn> <target_ip>
#:              AddRecord.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The target Fully Qualified Domain Name (e.g. "://example.com").
#:   $2         [Required] The target IPv4 address destination tracking node.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/dns/linode/<orchestration_tool>/{get_domains,create_record}.sh
#:   - External binaries: cat, echo, grep, cut, awk, jq
#:
#: Exit Codes:
#:   0          Target DNS A-record successfully provisioned and verified
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

# Validate that both FQDN and target IP arguments were provided
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Fully Qualified Domain Name and target IP parameters are required."
        status "Usage: $0 <fqdn> <target_ip>"
        exit 1
fi

# Split the FQDN into its leading subdomain label and base domain zone
sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
ip="${2}"

# Retrieve the active DNS provider choice from deployment context
set +e
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"
set -e

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

# Query the Linode DNS domain catalog via the active orchestration wrapper
set +e
domain_json="$("${BUILD_HOME}/services/dns/linode/${orchestration_tool}/get_domains.sh")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        status "Failed to query cluster domain management catalog or network timeout occurred."
        exit 1
fi

# Check the returned catalog payload for provider API error objects
if /bin/echo "${domain_json}" | /usr/bin/jq -e 'type == "object" and has("errors")' >/dev/null 2>&1
then
        err_msg="$(/bin/echo "${domain_json}" | /usr/bin/jq -r '.errors[0].reason // "Unknown API error parameters."')"
        status "Failed to retrieve domains list. Cloud Provider Reason: ${err_msg}"
        exit 1
fi

# Extract the matching domain zone ID (supporting both API .data[] and CLI .[] JSON shapes)
domain_id="$(/bin/echo "${domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '(if type == "object" and has("data") then .data else . end)[] | select(.domain | contains($dom)) | .id // empty' 2>/dev/null)"

if [ -z "${domain_id}" ]
then
        /bin/echo "Domain ID not found matching zone track string pattern: ${domain_url}" >&2
        exit 1
fi

# Build the JSON A-record creation payload with a 60-second TTL
json_payload="$(/bin/cat <<EOF
{
  "type": "A",
  "name": "${sub_domain}",
  "target": "${ip}",
  "ttl_sec": 60
}
EOF
)"

# Dispatch the record creation request to the active orchestration wrapper
set +e
record_response="$("${BUILD_HOME}/services/dns/linode/${orchestration_tool}/create_record.sh" "${domain_id}" "${json_payload}")"
record_exit_code="$?"
set -e

if [ "${record_exit_code}" -ne 0 ]
then
        status "Failed to add record to DNS system (Network/Curl infrastructure execution error)."
        exit 1
fi

# Check the creation response for provider API error objects
if /bin/echo "${record_response}" | /usr/bin/jq -e 'type == "object" and has("errors")' >/dev/null 2>&1
then
        record_err_msg="$(/bin/echo "${record_response}" | /usr/bin/jq -r '.errors[0].reason // "Unknown DNS payload entry validation error."')"
        status "Failed to add record to DNS system. Cloud Provider Reason: ${record_err_msg}"
        exit 1
fi

status "DNS record successfully added: ${sub_domain}.${domain_url} -> ${ip} [TTL: 60s]"
exit 0

