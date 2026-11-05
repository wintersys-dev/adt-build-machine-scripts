#!/bin/sh
###################################################################################
# @file        DeleteRecord.sh
# @brief       Deletes an active record entry from a specified Cloudflare DNS zone matrix.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses a target website URL to extract its zone apex domain root,
#              resolves or instantiates the target zone envelope using secondary toolkit 
#              dependencies, evaluates the authentication layout to determine API parsing 
#              protocols, and issues a secure authorized DELETE transaction payload.
#
# @param       $1  [Required] The unique platform identifier ID of the target DNS record.
# @param       $2  [Required] The Fully Qualified Domain Name context (e.g., "://domain.com").
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
# @exit        0  Success: Cloudflare DNS record entry successfully deleted and verified.
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
        status "Error: Record ID and Website URL parameters are required."
        status "Usage: $0 <record_id> <website_url>"
        exit 1
fi

record_id="${1}"
website_url="${2}"

# Extract structural configuration contexts securely via modern subshells
DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"
DNS_SECURITY_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_SECURITY_KEY)"
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

# Parse apex zone identifier safely using modern subshells
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

# Determine authentication layout structure and execute API endpoint communication safely
set +e
if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        # Parse out isolated API token authorization strings cleanly
        api_token="$(/bin/echo "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $2}')"
        
        api_response="$(/bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" -H "Content-Type: application/json")"
else
        # Fall back to traditional legacy X-Auth credential parameter signatures
        api_response="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json")"
fi
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Failed to delete record from DNS system with id: ${record_id} and url: ${website_url} (Network/Curl connection error)."
        exit 1
fi

# Verify final transaction payload state explicitly to catch schema rejections or token faults
if /bin/echo "${api_response}" | /usr/bin/jq -e '.success == false or .errors and (.errors | length > 0)' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[0].message // "Unknown Cloudflare entry deletion validation error."')"
        status "Failed to delete record from DNS system. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

status "Cloudflare DNS record entry successfully expunged: ID ${record_id} removed from zone ${zone_name}."
exit 0

