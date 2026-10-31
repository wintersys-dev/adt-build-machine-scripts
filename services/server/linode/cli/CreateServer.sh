#!/bin/sh
###################################################################################
# @file        CreateServer.sh
# @brief       Provisions a Linode compute instance securely within a managed VPC.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script connects to the Linode CLI to provision a virtual
#              machine. It validates the existence of the targeted Virtual Private
#              Cloud (VPC), dynamically creates the VPC and its core subnet if 
#              missing, resolves the relevant internal subnet IDs, and executes 
#              the final infrastructure deployment transaction securely using 
#              isolated local environment context tracking.
#
# @param       $1  [Required] The target Linode region slug for deployment location.
# @param       $2  [Required] The OS distribution image slug or custom image source.
# @param       $3  [Required] The server plan hardware size and performance profile tier.
# @param       $4  [Required] The human-readable label/hostname for the instance.
# @param       $5  [Required] Path to the prepared cloud-init user data file.
# @param       $6  [Required] The security firewall ID applied to the primary interface.
# @param       $7  [Optional] Overriding backup snapshot ID matching a recovery build.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
# @env         VPC_IP_RANGE        The network block CIDR configured for VPC initialization.
# @env         VPC_NAME            The matching environment tag pattern for infrastructure filtering.
# @env         TOKEN               The active Linode API Bearer security credentials string.
# @env         EMERGENCY_PASSWORD  Needs to be exported from above as its security sensitive.
# @env         REGION              The region that the servers are running in.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - external dependencies: linode-cli, jq, base64, sed, tail, cat, mkdir, dirname, date
#
# @security    
#              - Limits exposure of sensitive variables using isolated token scoping.
#              - Hardens system-owned paths (/bin, /usr/bin, /usr/local/bin) to eliminate executable hijack vectors.
#              - Wraps API and CLI data extractions safely in localized variables.
#
# @exit        0  Success: The server instance was successfully instantiated and registered.
# @exit        1  Failure: Argument mismatch, invalid VPC configurations, or an unexpected
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

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Input validation
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ] || [ -z "${6}" ] 
then
        status "Error: 6 arguments are required and 1 optional argument"
        status "Usage: $0 <region> <image> <server_size> <server_name> <user_data> <firewall_id> [snapshot_id]" 
        exit 1
fi

region="${1}"
image="${2}"
server_size="${3}"
server_name="${4}"
user_data_path="${5}"
firewall_id="${6}"
snapshot_id="${7}"

# Defensive check for structural credentials exposure
if [ -z "${EMERGENCY_PASSWORD}" ]
then
        status "Error: EMERGENCY_PASSWORD environment variable not set"
        exit 1
fi

if [ -n "${snapshot_id}" ]
then
        image="${snapshot_id}"
fi

# Secure framework configuration value extraction
VPC_IP_RANGE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)"
VPC_NAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_NAME)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

# Inject context variable securely for the local runtime tracking layer
export LINODE_CLI_TOKEN="${TOKEN}"

# Evaluate the active platform VPC landscape topology via safe CLI execution
vpc_id="$(/usr/local/bin/linode-cli --no-defaults --json vpcs list | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '.[] | select(.label == $lbl).id')"

if [ -z "${vpc_id}" ] 
then
        status "VPC network not found. Initiating dynamic deployment schema..."
        /usr/local/bin/linode-cli --no-defaults --json vpcs create --label "${VPC_NAME}" --region "${REGION}" --subnets.label "adt-subnet" --subnets.ipv4 "${VPC_IP_RANGE}"
fi

# Refresh identifiers tracking the target workspace
vpc_id="$(/usr/local/bin/linode-cli --no-defaults --json vpcs list | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '.[] | select(.label == $lbl).id')"
subnet_id="$(/usr/local/bin/linode-cli --no-defaults --json vpcs subnets-list "${vpc_id}" | /usr/bin/jq -r --arg lbl "adt-subnet" '.[] | select(.label == $lbl).id')"

if [ -z "${subnet_id}" ] 
then
        status "Error: Failed to obtain VPC subnet id mapping rules."
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Base64 package processing safely isolated
user_data_encoded="$(/bin/cat "${user_data_path}" | /usr/bin/base64 -w 0)"

# Dynamically bundle interfaces layout safely via jq
interfaces="$(/usr/bin/jq -n --argjson fw_id "${firewall_id}" --argjson sub_id "${subnet_id}" '[ { "firewall_id": $fw_id, "vpc": { "subnet_id": $sub_id, "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ]')"

# Temporary disable set -e to handle the server validation response state manually
set +e

/usr/local/bin/linode-cli --no-defaults --json linodes create --root_pass "${EMERGENCY_PASSWORD}" --region "${region}" --image "${image}" --type "${server_size}" --label "${server_name}" --no-defaults --interface_generation linode --interfaces "${interfaces}" --metadata.user_data "${user_data_encoded}" --disk_encryption enabled
cli_exit_code="$?"

# Restore strict environment checking mechanics
set -e

if [ "${cli_exit_code}" -ne 0 ]
then
        status "Error: Linode instance deployment failed via Linode CLI." >&2
        unset LINODE_CLI_TOKEN
        exit 1
fi

status "Success: Compute instance '${server_name}' successfully provisioned."
unset LINODE_CLI_TOKEN
exit 0
