#!/bin/sh
###################################################################################
# @file        GetIPAddresses.sh
# @brief       Resolves destination IPv4 addresses for a targeted FQDN via Cloudflare.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses a target website URL to extract its zone apex domain root,
#              resolves or instantiates the target zone envelope using secondary toolkit 
#              dependencies, evaluates the authentication layout to determine API parsing 
#              protocols, and queries Cloudflare for A-record IP content targets.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "://domain.com").
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
# @exit        0  Success: Target DNS record target IP configurations resolved cleanly.
# @exit        1  Failure: Missing context paths, input parameter errors, or API failures.
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
        status "Error: Website URL parameter is required."
        status "Usage: $0 <website_url>"
        exit 1
fi

website_url="${1}"

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
        
        api_response="$(/bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${website_url}" -H "Content-Type: application/json")"
else
        # Fall back to traditional legacy X-Auth credential parameter signatures
        api_response="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${website_url}" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json")"
fi
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Failed to get IP addresses for domain ${website_url} (Network/Curl connection error)."
        exit 1
fi

# Verify final transaction payload state explicitly to catch schema rejections or token faults
if /bin/echo "${api_response}" | /usr/bin/jq -e '.success == false or .errors and (.errors | length > 0)' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors.message // "Unknown Cloudflare IP lookup validation error."')"
        status "Failed to look up IP addresses for domain ${website_url}. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

# Extract the matching unique domain target destination IPs cleanly
ip_addresses="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.result[].content // empty')"

if [ -z "${ip_addresses}" ]
then
        status "No active destination A-record contents found matching name '${website_url}' inside zone '${zone_name}'."
        exit 1
fi

/bin/echo "${ip_addresses}"
exit 0
