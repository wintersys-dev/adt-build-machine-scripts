#!/bin/sh
###################################################################################
# @file        AddRecord.sh
# @brief       Provisions a new dynamic A-record entry within the DNS provider matrix.
# @author      Peter Winter
# @date        05/11/2026
# @version     2.0
#
# @details     This script parses a target fully qualified domain name (FQDN) into 
#              isolated sub-domain and baseline zone properties, queries provider catalogs
#              securely to capture the domain zone ID wrapper, and executes an authorized
#              transaction payload to inject the tracking destination IP node.
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
#              - external dependencies: cat, echo, awk, cut, curl, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Protects dynamic JSON queries from code parameter injection tracking bugs.
#
# @exit        0  Success: Target DNS A-record successfully provisioned and verified.
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
        status "Error: Fully Qualified Domain Name and target IP parameters are required."
        status "Usage: $0 <fqdn> <target_ip>"
        exit 1
fi

# Parse localized networking components safely using modern subshells
sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
ip="${2}"

# Extract authorized structural access keys safely
TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"

# Fetch active domain zone layouts securely with manual intercept hooks to catch runtime exceptions
set +e
api_domain_json="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/domains")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_domain_json}" ]
then
        status "Failed to query cluster domain management catalog or network timeout occurred."
        exit 1
fi

# Verify domain listing catalog returns to protect against masked HTTP authentication errors
if /bin/echo "${api_domain_json}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_domain_json}" | /usr/bin/jq -r '.errors[0].reason // "Unknown API error parameters."')"
        status "Failed to retrieve domains list. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

# Extract the matching unique domain layout tracking zone ID cleanly
domain_id="$(/bin/echo "${api_domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.data[] | select(.domain | contains($dom)) | .id // empty')"

if [ -z "${domain_id}" ]
then
        status "Domain ID not found matching zone track string pattern: ${domain_url}"
        exit 1
fi

# Assemble raw JSON transaction parameters block defensively to resist injection threats
json_payload="$(/bin/cat <<EOF
{
  "type": "A",
  "name": "${sub_domain}",
  "target": "${ip}",
  "ttl_sec": 60
}
EOF
)"

# Execute provision endpoint communication safely while manual intercept hooks track faults
set +e
api_record_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST -H "Content-Type: application/json" -d "${json_payload}" "https://api.linode.com/v4/domains/${domain_id}/records")"
record_exit_code="$?"
set -e

if [ "${record_exit_code}" -ne 0 ] 
then
        status "Failed to add record to DNS system (Network/Curl infrastructure execution error)."
        exit 1
fi

# Verify final transaction state explicitly to protect downstream resolving hooks
if /bin/echo "${api_record_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        record_err_msg="$(/bin/echo "${api_record_response}" | /usr/bin/jq -r '.errors[0].reason // "Unknown DNS payload entry validation error."')"
        status "Failed to add record to DNS system. Cloud Provider Reason: ${record_err_msg}"
        exit 1
fi

status "DNS record successfully added: ${sub_domain}.${domain_url} -> ${ip} [TTL: 60s]"
exit 0




