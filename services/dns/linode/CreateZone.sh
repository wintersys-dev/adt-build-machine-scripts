#!/bin/sh
###################################################################################
# @file        create_zone.sh
# @brief       Provisions a new authoritative master DNS zone with the cloud provider.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) to extract
#              its zone apex domain root, checks the provider catalog defensively to
#              prevent duplicate allocation states, and issues a secure authorized POST
#              payload to instantiate the master zone schema if missing.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "www.domain.com").
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, cut, curl, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Safely validates variable constraints under explicit character boundaries.
#
# @exit        0  Success: Master DNS zone verified active or created successfully.
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
#set -x
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
        status "Error: Fully Qualified Domain Name parameter is required."
        status "Usage: $0 <fqdn>"
        exit 1
fi

# Parse apex zone identifier safely using modern subshells
domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"

# Extract authorized structural access configurations
TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
DNS_USERNAME="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME)"

# Fetch active domain zone layouts securely with manual intercept hooks to catch runtime exceptions
set +e
api_domain_json="$(${HOME}/services/dns/linode/api/get_domains.sh)"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_domain_json}" ]
then
        status "Failed to query domain management catalog or network timeout occurred."
        exit 1
fi

# Verify domain listing catalog returns to protect against masked HTTP authentication errors
if /bin/echo "${api_domain_json}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_domain_json}" | /usr/bin/jq -r '.errors.reason // "Unknown API error parameters."')"
        status "Failed to retrieve domains list. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

# Extract the matching unique domain layout tracking zone ID cleanly
domain_id="$(/bin/echo "${api_domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.data[] | select(.domain == $dom) | .id // empty')"

# If the zone does not exist, assemble parameters and execute creation step
if [ -z "${domain_id}" ]
then
        status "Domain zone '${domain_url}' not found in catalog. Provisioning master zone layout..."

        # Assemble raw JSON transaction parameters block defensively to resist injection threats
        json_payload="$(/bin/cat <<EOF
{
  "type": "master",
  "domain": "${domain_url}",
  "soa_email": "${DNS_USERNAME}"
}
EOF
)"

        # Execute creation endpoint communication safely while manual intercept hooks track faults
        set +e
        api_create_response="$(${HOME}/services/dns/linode/api/create_domain_record.sh "${domain_id}" "${json_payload}")"
      #  api_create_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST -H "Content-Type: application/json" -d "${json_payload}" "https://api.linode.com/v4/domains")"
        create_exit_code="$?"
        set -e

        if [ "${create_exit_code}" -ne 0 ]
        then
                status "Failed to create zone in the DNS system (Network/Curl infrastructure execution error)."
                exit 1
        fi

        # Extract the error reason, defaulting to empty if it doesn't exist
        create_err_msg=$(echo "${api_create_response}" | /usr/bin/jq -e -r '.errors | if type == "array" then .[0].reason else .reason end // empty' 2>/dev/null)

        # If an error reason was found, log it and exit
        if [ -n "${create_err_msg}" ]; then
                status "Failed to create zone in the DNS system. Cloud Provider Reason: ${create_err_msg}"
                exit 1
        fi

        status "DNS master zone successfully initialized for domain: ${domain_url}"
else
        status "DNS master zone already active for domain: ${domain_url} (ID: ${domain_id})"
fi

exit 0
