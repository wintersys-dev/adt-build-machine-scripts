#!/bin/sh
###################################################################################
# @file        update_dbaas_firewall.sh
# @brief       Updates network firewall access control lists for a managed DBaaS instance via CLI.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script validates a target database instance ID and its corresponding
#              network configuration parameters, interfaces with the provider CLI utility
#              using bounded credential tokens, and monitors execution tracking codes 
#              defensively to confirm rule changes.
#
# @param       $1  [Required] The unique platform identifier ID of the active database instance.
# @param       $2  [Required] Comma-separated or properly formatted IP/CIDR string array definition.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, linode-cli
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Scopes and purges sensitive tokens (LINODE_CLI_TOKEN) tightly inside execution tracks.
#              - Protects structural parameter variables securely in strict text boundaries.
#
# @exit        0  Success: Target database network access control rules modified cleanly via CLI.
# @exit        1  Failure: Missing context paths, input parameters validation error, or CLI failures.
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
        status "Error: Database ID and allow_list parameters are required."
        status "Usage: $0 <database_id> <allow_list>"
        exit 1
fi

database_id="${1}"
allow_list="${2}"

# Framework deployment variables extraction using secure subshells
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Export authentication credentials safely within bounded local environment execution tracks
export LINODE_CLI_TOKEN="${TOKEN}"

# Validate CLI execution dependencies before invoking structural deployment steps
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Execute firewall access list network updates while manual trackers trap faults
set +e
"/usr/local/bin/linode-cli" databases postgresql-update "${database_id}" --allow_list "${allow_list}" --no-defaults
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] 
then
        status "Database ${database_id} firewall allow list failed to update via Linode CLI."
        unset LINODE_CLI_TOKEN
        exit 1
fi

status "Database ${database_id} firewall access network settings successfully modified via CLI."
unset LINODE_CLI_TOKEN

exit 0
