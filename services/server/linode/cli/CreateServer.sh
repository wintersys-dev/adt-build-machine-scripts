#!/bin/sh
###################################################################################
# @file        CreateServer.sh
# @brief       Provisions a Linode compute instance securely within a managed VPC.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script connects to the Linode v4 API to provision a virtual
#              machine. It validates the existence of the targeted Virtual Private
#              Cloud (VPC), dynamically creates the VPC and its core subnet if 
#              missing, resolves the relevant internal subnet IDs, and executes 
#              the final infrastructure deployment transaction securely using 
#              piped authorization streams.
#
# @param       $1  [Required] The target Linode region slug for deployment location.
# @param       $2  [Required] The OS distribution image slug or custom image source.
# @param       $3  [Required] The server plan hardware size and performance profile tier.
# @param       $4  [Required] The human-readable label/hostname for the instance.
# @param       $5  [Required] Path to the prepared cloud-init user data file.
# @param       $6  [Required] The security firewall ID applied to the primary interface.
# @param       $7  [Optional] Overriding backup snapshot ID matching a recovery build.
#
# @env         BUILD_HOME     Path to the toolkit core framework layout directory.
# @env         VPC_IP_RANGE   The network block CIDR configured for VPC initialization.
# @env         VPC_NAME       The matching environment tag pattern for infrastructure filtering.
# @env         TOKEN          The active Linode API Bearer security credentials string.
# @env         EMERGENCY_PASSWORD  Needs to be exported from above as its security sensitive
# @env         REGION         The region that the servers are running in 
#
# @exit        0  Success: The server instance was successfully instantiated and registered.
# @exit        1  Failure: Argument mismatch, invalid VPC configurations, or an unexpected
#                 HTTP error encountered during processing via the cloud host provider API.
#
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

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ] || [ "${5}" = "" ] || [ "${6}" = "" ]  )
then
        status "Error: 6 arguments are required and 1 optional argument"
        status "Usage: $0 <region> <image> <server_size> <server_name> <user_data> <firewall_id> [snapshot_id]" 
        exit 1
fi

region="${1}"
image="${2}"
server_size="${3}"
server_name="${4}"
user_data="${5}"
firewall_id="${6}"
snapshot_id="${7}"

if ( [ "${EMERGENCY_PASSWORD}" = "" ] )
then
        status "Error: EMERGENCY_PASSWORD environment variable not set"
        exit 1
fi

if ( [ "${snapshot_id}" != "" ] )
then
        image="${snapshot_id}"
fi

VPC_IP_RANGE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)"
VPC_NAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_NAME)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

export LINODE_CLI_TOKEN="${TOKEN}"

if ( [ "`/usr/local/bin/linode-cli --no-defaults --json vpcs list | /usr/bin/jq -r '.[] | select (.label == "'${VPC_NAME}'").id'`" = "" ] )
then
        /usr/local/bin/linode-cli --no-defaults --json vpcs create --label ${VPC_NAME} --region ${REGION} --subnets.label adt-subnet --subnets.ipv4 ${VPC_IP_RANGE}
fi

vpc_id="`/usr/local/bin/linode-cli --no-defaults --json vpcs list | /usr/bin/jq -r '.[] | select (.label == "'${VPC_NAME}'").id'`"
subnet_id="`/usr/local/bin/linode-cli --no-defaults --json vpcs subnets-list ${vpc_id}  | /usr/bin/jq  -r '.[] | select (.label == "adt-subnet").id'`"

user_data="$(/bin/cat ${user_data} | /usr/bin/base64 -w 0)"

interfaces=$(jq -n --argjson fw_id "${firewall_id}" --argjson sub_id "${subnet_id}" '[ { "firewall_id": $fw_id, "vpc": { "subnet_id": $sub_id, "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ]')

/usr/local/bin/linode-cli --no-defaults --json linodes create --root_pass "${EMERGENCY_PASSWORD}"  --region "${REGION}" --image "${image}" --type "${server_size}" --label "${server_name}" --no-defaults --interface_generation linode --interfaces "${interfaces}" --metadata.user_data "${user_data}" --disk_encryption enabled

unset LINODE_CLI_TOKEN

if ( [ "$?" != "0" ] )
then
        exit 1
fi
