#!/bin/sh
#: Name:        CreateZone.sh
#: Purpose:     Provisions a new authoritative master DNS zone within the Linode DNS provider matrix.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       CreateZone.sh <fqdn>
#:              CreateZone.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The target Fully Qualified Domain Name (e.g. "://example.com")
#:                         or apex domain name (e.g. "example.com").
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/dns/<dns_choice>/<orchestration_tool>/{get_domains,create_record}.sh
#:   - External binaries: cat, echo, grep, cut, awk, jq
#:
#: Exit Codes:
#:   0          Authoritative master DNS zone verified active or created cleanly
#:   1          Missing context paths, input parameter errors, or provider failures
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

# Validate that the required FQDN or apex domain argument was provided
if [ -z "${1}" ]
then
        status "Error: Fully Qualified Domain Name or root domain parameter is required."
        status "Usage: $0 <fqdn>"
        exit 1
fi

# Strip any leading host subdomain to isolate the apex root domain zone
dot_count="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print NF-1}')"
if [ "${dot_count}" -ge 2 ]
then
        domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
else
        domain_url="${1}"
fi

# Retrieve the active DNS provider and SOA admin email from deployment context
set +e
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"
DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"
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
domain_json="$("${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/get_domains.sh")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        status "Failed to query cluster domain management catalog or network timeout occurred."
        exit 1
fi

# Inspect the returned catalog payload for provider API error objects
err_msg="$(/bin/echo "${domain_json}" | /usr/bin/jq -r 'if type == "object" and .errors then (.errors | if type == "array" then .[0].reason elif type == "object" then .reason elif type == "string" and length > 0 then . else empty end) else empty end // empty' 2>/dev/null)"

if [ -n "${err_msg}" ]
then
        status "Failed to retrieve domains list. Cloud Provider Reason: ${err_msg}"
        exit 1
fi

# Check whether the zone already exists (supporting both API .data[] and CLI .[] JSON shapes)
domain_id="$(/bin/echo "${domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '(if type == "object" and has("data") then .data else . end)[] | select(.domain | contains($dom)) | .id // empty' 2>/dev/null)"

if [ -z "${domain_id}" ]
then
        /bin/echo "Domain ID not found matching zone track string pattern: ${domain_url}" >&2
        status "Domain zone '${domain_url}' not found in catalog. Provisioning master zone layout..."
else
        status "Domain zone '${domain_url}' found in catalog. Not provisioning master zone layout..."
        exit 0
fi

# Build the JSON master DNS zone payload with the configured SOA email
json_payload="$(/bin/cat <<EOF
{
  "type": "master",
  "domain": "${domain_url}",
  "soa_email": "${DNS_USERNAME}"
}
EOF
)"

# Dispatch master zone creation through create_record.sh using the 'zone' target sentinel
set +e
zone_response="$("${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/create_record.sh" "zone" "${json_payload}")"
zone_exit_code="$?"
set -e

if [ "${zone_exit_code}" -ne 0 ]
then
        status "Failed to create DNS master zone for '${domain_url}' (Infrastructure execution error)."
        exit 1
fi

# Inspect the creation response for provider API error objects
zone_err_msg="$(/bin/echo "${zone_response}" | /usr/bin/jq -r '(if type == "array" then first else . end) | if type == "object" and .errors then (.errors | if type == "array" then first.reason elif type == "object" then .reason elif type == "string" and length > 0 then . else empty end) else empty end // empty' 2>/dev/null)"

if [ -n "${zone_err_msg}" ]
then
        status "Failed to create DNS master zone. Cloud Provider Reason: ${zone_err_msg}"
        exit 1
fi

status "DNS master zone successfully created for domain: ${domain_url} [SOA: ${DNS_USERNAME}]"
exit 0


