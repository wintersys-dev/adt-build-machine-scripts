#!/bin/sh
########################################################################################
# @file        UpdateFirewall.sh
# @brief       Applies a custom network ruleset payload to a specified Linode firewall via the CLI.
# @author      Peter Winter
# @date        06/11/2026
# @version     1.0
#
# @details     This script utilizes the external Linode CLI utility to update the inbound security 
#              rules framework for an active firewall, targeted by its unique system ID. It maps a 
#              dynamically evaluated ruleset JSON array configuration straight onto the firewall engine.
#
# @param       $1  [Required] The unique system ID of the target Linode firewall to be updated.
# @param       $2  [Required] The computed raw JSON string ruleset payload to append.
#
# @env         BUILD_HOME          Path to the framework root directory (read from file).
# @env         TOKEN               Linode API bearer authorization token.
# @env         LINODE_CLI_TOKEN    Exported environment token required by the Linode CLI binary.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - external dependencies: linode-cli, cat, echo
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/local/bin) to eliminate hijack vectors.
#              - Safely unsets exposed token variables from the localized shell environment upon completion.
#
# @exit        0  Success: The firewall ruleset payload was correctly updated.
# @exit        1  Failure: Missing arguments, missing configuration, or remote API rejection via CLI.
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

# Export CLI credential contexts securely into the active process boundary
export LINODE_CLI_TOKEN="${TOKEN}"

# Temporary disable set -e to evaluate the CLI command outcome manually
set +e
/usr/local/bin/linode-cli firewalls rules-update --inbound "${ruleset}" "${firewall_id}" 2>/dev/null
cli_status="$?"
set -e

# Instantly strip out credentials from the runtime context boundary
unset LINODE_CLI_TOKEN

if [ "${cli_status}" -ne 0 ]
then
        status "Unable to update firewall rules"
        exit 1
fi

exit 0
