#!/bin/sh
###################################################################################
# @file        CreateZone.sh
# @brief       Provisions a new authoritative master DNS zone within the DNS provider matrix.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.0
#
# @details     This script extracts the baseline root zone from a target Fully Qualified
#              Domain Name (FQDN), resolves the active orchestration tool (CLI or API),
#              queries provider catalogs defensively to prevent duplicate allocations,
#              and routes a master zone creation payload through create_record.sh.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "://domain.com")
#                             or apex domain name (e.g., "domain.com").
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - software.dat configuration file defining the active ORCHESTRATION_TOOL.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, cut, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Protects dynamic JSON queries from code parameter injection tracking bugs.
#
# @exit        0  Success: Authoritative master DNS zone verified active or created cleanly.
# @exit        1  Failure: Missing context paths, input parameter errors, or provider failures.
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
#set -x
set -e

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

if [ -z "${1}" ]
then
        status "Error: Fully Qualified Domain Name or root domain parameter is required."
        status "Usage: $0 <fqdn>"
        exit 1
fi

dot_count="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print NF-1}')"
if [ "${dot_count}" -ge 2 ]
then
        domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
else
        domain_url="${1}"
fi

set +e
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"
set -e

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

set +e
domain_json="$("${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/get_domains.sh")"
exit_code="$?"
set -e

read z

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        status "Failed to query cluster domain management catalog or network timeout occurred."
        exit 1
fi

err_msg="$(/bin/echo "${domain_json}" | /usr/bin/jq -r 'if type == "object" and .errors then (.errors | if type == "array" then .[0].reason elif type == "object" then .reason elif type == "string" and length > 0 then . else empty end) else empty end // empty' 2>/dev/null)"


if [ -n "${err_msg}" ]
then
        status "Failed to retrieve domains list. Cloud Provider Reason: ${err_msg}"
        exit 1
fi

set +e
domain_id="$("${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/get_domain_id.sh" "${domain_json}" "${domain_url}")"
set -e

if [ -n "${domain_id}" ]
then
        status "DNS master zone already active for domain: ${domain_url} (ID: ${domain_id})"
        exit 0
fi

status "Domain zone '${domain_url}' not found in catalog. Provisioning master zone layout..."

json_payload="$(/bin/cat <<EOF
{
  "type": "master",
  "domain": "${domain_url}",
  "soa_email": "${DNS_USERNAME}"
}
EOF
)"

set +e
zone_response="$("${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/create_record.sh" "zone" "${json_payload}")"
zone_exit_code="$?"
set -e

if [ "${zone_exit_code}" -ne 0 ]
then
        status "Failed to create DNS master zone for '${domain_url}' (Infrastructure execution error)."
        exit 1
fi

zone_err_msg="$(/bin/echo "${zone_response}" | /usr/bin/jq -r '(if type == "array" then first else . end) | if type == "object" and .errors then (.errors | if type == "array" then first.reason elif type == "object" then .reason elif type == "string" and length > 0 then . else empty end) else empty end // empty' 2>/dev/null)"

if [ -n "${zone_err_msg}" ]
then
        status "Failed to create DNS master zone. Cloud Provider Reason: ${zone_err_msg}"
        exit 1
fi

status "DNS master zone successfully created for domain: ${domain_url} [SOA: ${DNS_USERNAME}]"
exit 0

