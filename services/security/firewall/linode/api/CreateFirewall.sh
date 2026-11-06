#!/bin/sh
########################################################################################
# @file        CreateFirewall.sh
# @brief       Creates a new Linode native firewall instance with secure base policies.
# @author      Peter Winter
# @date        06/11/2026
# @version     1.0
#
# @details     This script connects to the Linode v4 API, provisions a new Cloud Firewall,
#              sets default inbound filtering to DROP, and sets outbound filtering to ACCEPT.
#              It appends the active deployment build ID to keep resources isolated.
#
# @param       $1  [Required] The firewall base configuration profile / role name identifier.
#
# @env         BUILD_HOME          Path to the framework root directory (read from file).
# @env         TOKEN               Linode API bearer authorization token.
# @env         BUILD_IDENTIFIER    A unique build execution identifier used for resource segregation.
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
#              - Binds JSON construction safely inside an integrated jq initialization environment.
#
# @exit        0  Success: The firewall instance was registered and its ID returned on stdout.
# @exit        1  Failure: Missing arguments, missing configurations, or downstream transaction error.
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
if [ -z "${1}" ]
then
        status "Error: Firewall name argument is required."
        status "Usage: $0 <firewall_name>"
        exit 1
fi

firewall_name="${1}"

# Secure framework configuration value extraction
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"

if [ -z "${TOKEN}" ]
# Target routing token evaluation
then
        status "Error: API authorization TOKEN is empty or missing configuration."
        exit 1
fi

# Securely assemble payload structure
payload="$(/usr/bin/jq -n --arg lbl "${firewall_name}-${BUILD_IDENTIFIER}" '{label: $lbl, rules: {inbound_policy: "DROP", outbound_policy: "ACCEPT"}}')"

# Temporary disable set -e to evaluate curl transaction pipeline failures manually
set +e
response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST -H 'Content-Type: application/json' -d "${payload}" 'https://api.linode.com/v4/networking/firewalls')"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response}" ]
then
        output="$(/bin/echo "${response}" | /usr/bin/jq -r '.id')"

        if [ -z "${output}" ] || [ "${output}" = "null" ]
        then
                status "Unable to create firewall. API Response: ${response}"
                exit 1
        else
                /bin/echo "${output}"
        fi
else
        status "Network request failed. Check your API token or URL."
        exit 1
fi

exit 0
