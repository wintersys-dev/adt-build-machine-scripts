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

if  [ "$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/vpcs" | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '.data[] | select(.label == $lbl).id')" = "" ]
then
        vpc_payload="$(/usr/bin/jq -n --arg lbl "${VPC_NAME}" --arg reg "${REGION}" --arg ip "${VPC_IP_RANGE}" '{label: $lbl, region: $reg, subnets: [{label: "adt-subnet", ipv4: $ip}]}')"
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST "https://api.linode.com/v4/vpcs" -H "Content-Type: application/json" -d "${vpc_payload}"
fi

vpc_id="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/vpcs" | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '.data[] | select(.label == $lbl).id')"
subnet_id="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/vpcs/${vpc_id}/subnets" | /usr/bin/jq -r --arg lbl "adt-subnet" '.data[] | select(.label == $lbl).id')"

if ( [ "${subnet_id}" = "" ] )
then
        status "Failed to obtain VPC subnet id"
        exit 1
fi

user_data="$(/bin/cat ${user_data} | /usr/bin/base64 -w 0)"

# Temporary disable set -e to handle the error manually
set +e

instance_payload="$(/usr/bin/jq -n --arg pass "${EMERGENCY_PASSWORD}"  --arg reg "${region}" --arg img "${image}" --arg size "${server_size}" --arg name "${server_name}" --arg fw "${firewall_id}" --arg sub "${subnet_id}" --arg ud "${user_data}" '{ root_pass: $pass, region: $reg, image: $img, type: $size, label: $name, interface_generation: "linode", interfaces: [ { firewall_id: ($fw | tonumber), vpc: { subnet_id: ($sub | tonumber), ipv4: { addresses: [ { address: "auto", nat_1_1_address: "auto" } ] } } } ], metadata: { user_data: $ud }, disk_encryption: "enabled" }')"
raw_output=$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -f -s -X POST "https://api.linode.com/v4/linode/instances" -H "Content-Type: application/json" -d "${instance_payload}" -w "\n%{http_code}")

# Restore strict error checking
set -e

api_response=$(/bin/echo "${raw_output}" | /usr/bin/sed '$d')
http_code=$(/bin/echo "${raw_output}" | /usr/bin/tail -n 1)

if [ "${http_code}" -lt 200 ] || [ "${http_code}" -ge 300 ]
then
        status "Error: Linode instance deployment failed with HTTP status ${http_code}." >&2
        error_message=$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[].reason' 2>/dev/null || /bin/echo "Unknown API error: ${api_response}")
        status "Reason: ${error_message}" >&2
        exit 1
fi
