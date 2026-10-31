#!/bin/sh
###################################################################################
# @file        GetServerIPsByType.sh
# @brief       Retrieves all IP addresses for compute instances matching a type pattern.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script connects to the Linode CLI to list all active instances.
#              It securely filters the system inventory using a type/label pattern matching
#              routine and outputs the associated IPv4 address collection to stdout.
#
# @param       $1  [Required] The target server type substring pattern to filter labels by.
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
# @exit        0  Success: The matched IP addresses were extracted and displayed safely.
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

# Define log file destination path
LOG_FILE="${BUILD_HOME}/runtime/logs/provisioning/GetServerIPsByType.log"

# Unified status wrapper mimicking the original behavior and appending to log streams safely
status()
{
        # Execute the original framework status tool safely
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
        
        # Mirror output to dedicated runtime log if target directory is writable
        status_msg="[$(/bin/date '+%Y-%m-%d %H:%M:%S')] STATUS: ${1}"
        if [ -w "${LOG_FILE}" ] || [ -w "$(/usr/bin/dirname "${LOG_FILE}")" ]
        then
                /bin/echo "${status_msg}" >> "${LOG_FILE}"
        fi
}

# Input validation
if [ -z "${1}" ]
then
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>" 
        exit 1
fi

server_type="${1}"

# Secure framework configuration value extraction
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${TOKEN}"

# Temporary disable set -e to handle CLI error code validation matrices manually
set +e

# Safely extract IP data stream using parameterized jq variables
ip_list="$(/usr/local/bin/linode-cli --no-defaults --json linodes list | /usr/bin/jq -r --arg pattern "${server_type}" '.[] | select(.label | contains($pattern)).ipv4[]' 2>/dev/null)"
cli_exit_code="$?"

# Restore strict environment checking mechanics
set -e

if [ "${cli_exit_code}" -ne 0 ]
then
        status "Error: Linode instance query execution sequence failed." >&2
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Output the resolved network targets directly to stdout
if [ -n "${ip_list}" ]
then
        /bin/echo "${ip_list}"
fi

unset LINODE_CLI_TOKEN
exit 0
