#!/bin/sh
###################################################################################
# @file        DestroyServer.sh
# @brief       Decommissions and destroys a specific Linode instance by IP address.
# @author      Peter Winter
# @date        13/07/2016
# @version     1.0
#
# @details     This script connects to the Linode CLI to resolve a virtual machine 
#              instance ID using its recorded IPv4 address. It handles internal 
#              IP resolutions if required, gracefully initiates an instance 
#              shutdown transaction, monitors the power state until offline, and 
#              safely executes the final infrastructure deletion sequence.
#
# @param       $1  [Required] The target server IP address (Public or Private).
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
# @env         TOKEN               The active Linode API Bearer security credentials string.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - GetServerPublicIPAddressByIP.sh internal cross-reference IP lookup tool.
#              - external dependencies: linode-cli, jq, sleep, expr, cat, mkdir, dirname, date
#
# @security    
#              - Limits exposure of sensitive variables using isolated token scoping.
#              - Hardens system-owned paths (/bin, /usr/bin, /usr/local/bin) to eliminate executable hijack vectors.
#              - Wraps API and CLI data extractions safely in localized variables.
#
# @exit        0  Success: The server instance was safely shut down, verified offline, and deleted.
# @exit        1  Failure: Argument mismatch, instance could not be resolved, or an unexpected
#                 error encountered during processing via the cloud host provider CLI.
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
LOG_FILE="${BUILD_HOME}/runtime/logs/provisioning/DestroyServer.log"

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

# Locate server entry matching the provided IP address
server_id="$(/usr/local/bin/linode-cli --no-defaults --json linodes list | /usr/bin/jq -r --arg ip "${server_ip}" '.[] | select(.ipv4[] == $ip).id')"
cli_exit_code="$?"

if [ "${cli_exit_code}" -ne 0 ]
then
        status "Error: Failed to fetch instances from Linode CLI." >&2
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Attempt resolution via secondary cross-reference engine if first lookup fails
if [ -z "${server_id}" ]
then
        server_ip="$("${BUILD_HOME}/services/server/GetServerPublicIPAddressByIP.sh" "${server_ip}")"
        server_id="$(/usr/local/bin/linode-cli --no-defaults --json linodes list | /usr/bin/jq -r --arg ip "${server_ip}" '.[] | select(.ipv4[] == $ip).id')"
        cli_exit_code="$?"
        
        if [ "${cli_exit_code}" -ne 0 ]
        then
                status "Error: Failed to execute fall-back lookup via Linode CLI." >&2
                unset LINODE_CLI_TOKEN
                exit 1
        fi
fi

# Abort tracking execution if entity resolution yields no actionable identifier
if [ -z "${server_id}" ]
then
        status "Error: Could not locate compute instance associated with IP: ${server_ip}" >&2
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Dispatch graceful execution shutdown event hook 
/usr/local/bin/linode-cli linodes shutdown "${server_id}"
cli_exit_code="$?"

if [ "${cli_exit_code}" -ne 0 ]
then
        status "Error: Linode shutdown sequence failed for ID: ${server_id}." >&2
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Context block pooling tracking state changes iteratively
count="0"
while true
do
        current_status="$(/usr/local/bin/linode-cli --no-defaults --json linodes view "${server_id}" --format status --no-headers | /usr/bin/jq -r '.[].status')"
        
        if [ "${current_status}" = "offline" ]
        then
                break
        fi

        if [ "${count}" -ge 20 ]
        then
                status "Error: Timeout reached waiting for machine ID: ${server_id} to drop offline." >&2
                unset LINODE_CLI_TOKEN
                exit 1
        fi

        status "Waiting for machine with id: ${server_id} and ip address ${server_ip} to be offline following a shutdown request"
        /bin/sleep 10
        count="$(/usr/bin/expr ${count} + 1)"
done

# Perform final decommissioning deletion block sequence
/usr/local/bin/linode-cli --no-defaults --json linodes delete "${server_id}"
cli_exit_code="$?"

# Restore strict environment checking mechanics
set -e

if [ "${cli_exit_code}" -ne 0 ]
then
        status "Error: Linode instance deletion execution sequence failed." >&2
        unset LINODE_CLI_TOKEN
        exit 1
fi

status "Success: Machine with id: ${server_id} and ip address ${server_ip} has been deleted"
unset LINODE_CLI_TOKEN
exit 0
