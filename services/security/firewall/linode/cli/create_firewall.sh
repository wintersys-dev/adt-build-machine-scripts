#!/bin/sh
########################################################################################
# @file        create_firewall.sh
# @brief       Creates a new Linode native firewall using the Linode CLI orchestration engine.
# @author      Peter Winter
# @date        06/11/2026
# @version     1.0
#
# @details     This script utilizes the external Linode CLI utility to provision a cloud firewall.
#              It assigns a combined tier and build identifier label while setting standard 
#              inbound DROP and outbound ACCEPT isolation policies, returning the resource ID.
#
# @param       $1  [Required] The firewall base configuration profile / role name identifier.
#
# @env         BUILD_HOME          Path to the framework root directory (read from file).
# @env         TOKEN               Linode API bearer authorization token.
# @env         BUILD_IDENTIFIER    A unique build execution identifier used for resource segregation.
# @env         LINODE_CLI_TOKEN    Exported environment token required by the Linode CLI binary.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - external dependencies: linode-cli, jq, cat, echo
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin, /usr/local/bin) to eliminate hijack vectors.
#              - Safely unsets exposed token variables from the localized shell environment upon completion.
#
# @exit        0  Success: The firewall instance was registered and its ID returned on stdout.
# @exit        1  Failure: Missing arguments, missing configurations, or CLI transmission error.
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

# Export CLI credential contexts securely into the active process boundary
export LINODE_CLI_TOKEN="${TOKEN}"

# Temporary disable set -e to evaluate the CLI pipeline transaction manually
set +e
response="$(/usr/local/bin/linode-cli firewalls create --json --label "${firewall_name}-${BUILD_IDENTIFIER}" --rules.inbound_policy DROP --rules.outbound_policy ACCEPT 2>/dev/null)"
cli_status="$?"

if [ "${cli_status}" -eq 0 ] && [ -n "${response}" ]
then
        firewall_id="$(/bin/echo "${response}" | /usr/bin/jq -r '.[].id')"
else
        firewall_id=""
fi
set -e

# Instantly strip out credentials from the runtime context boundary
unset LINODE_CLI_TOKEN

if [ -z "${firewall_id}" ] || [ "${firewall_id}" = "null" ]
then
        status "Unable to create firewall"
        exit 1
else
        /bin/echo "${firewall_id}"
fi

exit 0
