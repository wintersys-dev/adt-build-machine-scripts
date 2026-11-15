#!/bin/sh
#: Name:        ProvisionServer.sh
#: Purpose:     Provisions a Linode compute instance securely within a managed VPC.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       ProvisionServer.sh <region> <image> <server_size> <server_name> <user_data_path> <firewall_id> [snapshot_id]
#:              ProvisionServer.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The target Linode region slug for deployment location.
#:   $2         [Required] The OS distribution image slug or custom image source.
#:   $3         [Required] The server plan hardware size and performance profile tier.
#:   $4         [Required] The human-readable label/hostname for the instance.
#:   $5         [Required] Path to the prepared cloud-init user data file.
#:   $6         [Required] The security firewall ID applied to the primary interface.
#:   $7         [Optional] Overriding backup snapshot ID matching a recovery build.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/server/linode/<orchestration_tool>/{list_vpcs,create_vpc,list_subnets,create_instance}.sh
#:   - External binaries: cat, echo, grep, cut, awk, tr, jq
#:
#: Exit Codes:
#:   0          Server instance was successfully instantiated and registered
#:   1          Missing arguments, invalid VPC config, or provider API/CLI failure
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
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

# Exit immediately if any command exits with a non-zero status
#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the system tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Validate that all 6 required provisioning parameters were supplied
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ] || [ -z "${6}" ]
then
        status "Error: 6 arguments are required and 1 optional argument"
        status "Usage: $0 <region> <image> <server_size> <server_name> <user_data_path> <firewall_id> [snapshot_id]"
        exit 1
fi

region="${1}"
image="${2}"
server_size="${3}"
server_name="${4}"
user_data_path="${5}"
firewall_id="${6}"
snapshot_id="${7}"

# Override base OS image slug when a recovery/golden snapshot ID is provided
if [ -n "${snapshot_id}" ]
then
        image="${snapshot_id}"
fi

# Retrieve VPC network parameters and region from active deployment context
VPC_IP_RANGE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)"
VPC_NAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_NAME)"
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION)"

# Read software.dat and resolve the active orchestration tool (cli or api)
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

if [ ! -d "${BUILD_HOME}/services/server/linode/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

# Query existing VPCs in the target region to check whether VPC_NAME already exists
set +e
response_vpc="$("${BUILD_HOME}/services/server/linode/${orchestration_tool}/list_vpcs.sh" "${REGION}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response_vpc}" ]
then
        # Support both API (.data[]) and CLI (.[]) JSON shapes
        vpc_id="$(/bin/echo "${response_vpc}" | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '(if type == "object" and has("data") then .data else . end)[] | select(.label == $lbl).id // empty')"
else
        status "Network request failed. Check your API token or URL."
        exit 1
fi

# Dynamically provision the VPC and default 'adt-subnet' if no matching VPC was found
if [ -z "${vpc_id}" ]
then
        status "VPC network not found. Initiating dynamic deployment schema..."
        if [ "${orchestration_tool}" = "api" ]
        then
                vpc_payload="$(/usr/bin/jq -n --arg lbl "${VPC_NAME}" --arg reg "${REGION}" --arg ip "${VPC_IP_RANGE}" '{label: $lbl, region: $reg, subnets: [{label: "adt-subnet", ipv4: $ip}]}')"
        elif [ "${orchestration_tool}" = "cli" ]
        then
                vpc_payload='--label "'${VPC_NAME}'" --region "'${REGION}'" --subnets.label "'adt-subnet'" --subnets.ipv4 "'${VPC_IP_RANGE}'"'
        fi

        set +e
        response_create_vpc="$("${BUILD_HOME}/services/server/linode/${orchestration_tool}/create_vpc.sh" "${vpc_payload}")"
        curl_status="$?"
        set -e

        if [ "${curl_status}" -eq 0 ] && [ -n "${response_create_vpc}" ]
        then
                # Extract the newly created VPC ID (supporting both API object and CLI array responses)
                vpc_id="$(/bin/echo "${response_create_vpc}" | /usr/bin/jq -r '(if type == "array" then first else . end).id // empty')"

                # Fallback refresh if the creation response omitted the new VPC ID
                if [ -z "${vpc_id}" ] || [ "${vpc_id}" = "null" ]
                then
                        set +e
                        response_vpc_refresh="$("${BUILD_HOME}/services/server/linode/${orchestration_tool}/list_vpcs.sh" "${REGION}")"
                        curl_status="$?"
                        set -e

                        if [ "${curl_status}" -eq 0 ] && [ -n "${response_vpc_refresh}" ]
                        then
                                vpc_id="$(/bin/echo "${response_vpc_refresh}" | /usr/bin/jq -r --arg lbl "${VPC_NAME}" '(if type == "object" and has("data") then .data else . end)[] | select(.label == $lbl).id // empty')"
                        else
                                status "Network request failed during VPC landscape refresh."
                                exit 1
                        fi
                fi
        else
                status "Network request failed. Dynamic VPC creation failed."
                exit 1
        fi
fi

# Query subnets within the resolved VPC and extract the ID for 'adt-subnet'
set +e
response_subnet="$("${BUILD_HOME}/services/server/linode/${orchestration_tool}/list_subnets.sh" "${vpc_id}")"
curl_status="$?"
set -e

if [ "${curl_status}" -eq 0 ] && [ -n "${response_subnet}" ]
then
        subnet_id="$(/bin/echo "${response_subnet}" | /usr/bin/jq -r --arg lbl "adt-subnet" '(if type == "object" and has("data") then .data else . end)[] | select(.label == $lbl).id // empty')"
else
        status "Network request failed. Check your API token or URL."
        exit 1
fi

if [ -z "${subnet_id}" ]
then
        status "Error: Failed to obtain VPC subnet id mapping rules."
        exit 1
fi

# Assemble the instance parameter payload and dispatch creation to the active provider wrapper
parameter_payload="${region} ${image} ${server_size} ${server_name} ${firewall_id} ${subnet_id} ${user_data_path}"

set +e
response_instance=$(/bin/echo "${parameter_payload}" | "${BUILD_HOME}/services/server/linode/${orchestration_tool}/create_instance.sh")
curl_status="$?"
set -e

# Verify successful compute instantiation and exit cleanly
if [ "${curl_status}" -eq 0 ] && [ -n "${response_instance}" ]
then
        status "Success: Compute instance '${server_name}' successfully provisioned."
        exit 0
else
        status "Network request failed. Check your API token or URL."
        exit 1
fi

