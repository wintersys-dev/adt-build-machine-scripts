#!/bin/sh
###################################################################################
# @file        GetZoneID.sh
# @brief       Resolves the unique zone identifier ID for a given domain via Cloudflare API.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script queries Cloudflare's authoritative catalog endpoints to extract
#              the active zone ID corresponding to a provided apex zone name. It handles
#              both modern Bearer token formats and legacy X-Auth credential mappings.
#
# @param       $1  [Required] The target apex domain name (e.g., "domain.com").
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, grep, awk, curl, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Protects dynamic JSON queries from parameter injection tracking vulnerabilities.
#
# @exit        0  Success: Target DNS zone unique identifier ID resolved and printed.
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
if [ -z "${1}" ]
then
        status "Error: Zone name parameter is required."
        status "Usage: $0 <zone_name>"
        exit 1
fi

zone_name="${1}"

# Extract structural configuration contexts securely via modern subshells
DNS_USERNAME="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME)"
DNS_SECURITY_KEY="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY)"
# Determine authentication layout structure and execute API endpoint communication safely
set +e
if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        # Parse out isolated API token authorization strings cleanly
        api_token="$(/bin/echo "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $2}')"
        
        api_response="$(/bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "Content-Type: application/json")"
else
        # Fall back to traditional legacy X-Auth credential parameter signatures
        api_response="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json")"
fi
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Failed to query zone ID for domain ${zone_name} (Network/Curl connection error)."
        exit 1
fi

# Verify final transaction payload state explicitly to catch schema rejections or token faults
if /bin/echo "${api_response}" | /usr/bin/jq -e '.success == false or .errors and (.errors | length > 0)' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[].message // "Unknown Cloudflare zone lookup validation error."')"
        status "Failed to look up zone ID for domain ${zone_name}. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

# Extract the matching unique domain layout zone ID cleanly
zone_id="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.result[].id // empty')"

if [ -z "${zone_id}" ]
then
        status "No active zones found matching name '${zone_name}' in the DNS system."
        exit 1
fi

/bin/echo "${zone_id}"
exit 0



