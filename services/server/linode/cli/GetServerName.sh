#!/bin/sh
###################################################################################
# @file        GetServerName.sh
# @brief       Retrieves the human-readable label/hostname of an instance by its IP.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script connects to the Linode CLI to list all active instances.
#              It securely filters the system infrastructure mapping configurations using
#              the target IPv4 address and outputs the resolved matching label to stdout.
#
# @param       $1  [Required] The target server IP address to search for.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
# @env         TOKEN               The active Linode API Bearer security credentials string.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - external dependencies: linode-cli, jq, cat, mkdir, dirname, date
#
# @security    
#              - Limits exposure of sensitive variables using isolated token scoping.
#              - Hardens system-owned paths (/bin, /usr/bin, /usr/local/bin) to eliminate executable hijack vectors.
#              - Wraps API and CLI data extractions safely in localized variables.
#
# @exit        0  Success: The matched hostname was extracted and displayed safely.
# @exit        1  Failure: Argument mismatch, or an unexpected error encountered during processing.
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

if [ ! -d "${BUILD_HOME}/runtime/logs/provisioning" ]
then
        /bin/mkdir -p "${BUILD_HOME}/runtime/logs/provisioning"
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Input validation
if [ -z "${1}" ]
then
        status "Error: Server ip argument is required."
        status "Usage: $0 <server_ip>" 
        exit 1
fi

server_ip="${1}"

# Secure framework configuration value extraction
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${TOKEN}"

# Temporary disable set -e to handle CLI error code validation matrices manually
set +e

# Safely extract matching instance hostname label using parameterized jq variables
server_name="$(/usr/local/bin/linode-cli --no-defaults --json linodes list | /usr/bin/jq -r --arg ip "${server_ip}" '.[] | select(.ipv4[] == $ip).label' 2>/dev/null)"
cli_exit_code="$?"

# Restore strict environment checking mechanics
set -e

if [ "${cli_exit_code}" -ne 0 ]
then
        status "Error: Linode instance query execution sequence failed." >&2
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Output the resolved hostname pattern directly to stdout
if [ -n "${server_name}" ]
then
        /bin/echo "${server_name}"
fi

unset LINODE_CLI_TOKEN
exit 0
