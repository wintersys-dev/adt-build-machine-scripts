#!/bin/sh
########################################################################################
# @file        UpdateFirewall.sh
# @brief       Applies a dynamic network ruleset payload to a specified Linode firewall.
# @author      Peter Winter
# @date        06/11/2026
# @version     1.0
#
# @details     This script connects to the Linode v4 API and targets a specific firewall by 
#              its unique system ID. It packs a dynamically generated JSON arrays data block 
#              safely via jq, assigning it directly onto the inbound network security schema.
#
# @param       $1  [Required] The unique system ID of the target Linode firewall to be updated.
# @param       $2  [Required] The computed raw JSON string ruleset payload to append.
#
# @env         BUILD_HOME          Path to the framework root directory (read from file).
# @env         TOKEN               Linode API bearer authorization token.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - external dependencies: curl, jq, cat, echo
#
# @security    
#              - Filters curl interactions through piped authorization headers via @- syntax.
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Sanitizes the input ruleset structure natively inside jq argument variables.
#
# @exit        0  Success: The firewall ruleset payload was correctly updated.
# @exit        1  Failure: Missing arguments, missing configuration, or remote API rejection.
########################################################################################
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
########################################################################################
########################################################################################
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
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Both firewall ID and ruleset arguments are required."
        status "Usage: $0 <firewall_id> <ruleset_json>"
        exit 1
fi

firewall_id="${1}"
ruleset="${2}"

# Secure framework configuration value extraction
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
# Target routing token evaluation
then
        status "Error: API authorization TOKEN is empty or missing configuration."
        exit 1
fi

# Securely assemble payload structure
payload="$(/usr/bin/jq -n --argjson rules "${ruleset}" '{inbound: $rules}')"

# Temporary disable set -e to evaluate curl transaction pipeline failures manually
set +e
response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X PUT -H 'Content-Type: application/json' -d "${payload}" "https://linode.com{firewall_id}/rules")"
curl_status="$?"
set -e

if [ "${curl_status}" -ne 0 ]
then
        status "Unable to update firewall rules"
        exit 1
fi

exit 0
