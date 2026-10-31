#!/bin/sh
###################################################################################
# @file        GetServerPublicIPByIP.sh
# @brief       Resolves an instance's public IP address based on its private VPC IP.
# @author      Peter Winter
# @date        13/06/2016
# @version     1.0
#
# @details     This script connects to the Linode CLI to pull a global mapping matrix 
#              of VPC network endpoints for the current active region. It extracts 
#              the static 1:1 NAT public IP address configured for a specific 
#              internal private VPC IP address and outputs it directly to stdout.
#
# @param       $1  [Required] The internal private VPC IP address to look up.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
# @env         TOKEN               The active Linode API Bearer security credentials string.
# @env         REGION              The region that the servers are running in.
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
# @exit        0  Success: The matched 1:1 NAT public IP address was retrieved and displayed.
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
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${TOKEN}"

# Temporary disable set -e to handle CLI error code validation matrices manually
set +e

# Safely extract matching 1:1 NAT public IP using parameterized jq variables
public_ip="$(/usr/local/bin/linode-cli --no-defaults --json vpcs ips-all-list --region "${REGION}" | /usr/bin/jq -r --arg ip "${server_ip}" '.[] | select(.address == $ip).nat_1_1' 2>/dev/null)"
cli_exit_code="$?"

# Restore strict environment checking mechanics
set -e

if [ "${cli_exit_code}" -ne 0 ]
then
        status "Error: Linode VPC IP query execution sequence failed." >&2
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Output the resolved IP address to stdout if found
if [ -n "${public_ip}" ] && [ "${public_ip}" != "null" ]
then
        /bin/echo "${public_ip}"
fi

unset LINODE_CLI_TOKEN
exit 0
