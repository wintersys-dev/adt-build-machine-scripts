#!/bin/sh
#set -x
set -e

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] )
then
        status "Error: 8 arguments are required and 1 optional argument"
        status "Usage: $0 <emergency_password> <region> <image> <server_size> <server_name> <subnet_id> <user_data> <firewall_id> [snapshot_id]" 
        exit 1
fi



emergency_password="${1}"
region="${2}"
image="${3}"
server_size="${4}"
server_name="${5}"
subnet_id="${6}"
user_data="${7}"
firewall_id="${8}"
snapshot_id="${9}"

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
        
# Temporary disable set -e to handle the error manually
set +e

instance_payload="$(/usr/bin/jq -n --arg pass "${emergency_password}"  --arg reg "${region}" --arg img "${image}" --arg size "${server_size}" --arg name "${server_name}" --arg fw "${firewall_id}" --arg sub "${subnet_id}" --arg ud "${user_data}" '{ root_pass: $pass, region: $reg, image: $img, type: $size, label: $name, interface_generation: "linode", interfaces: [ { firewall_id: ($fw | tonumber), vpc: { subnet_id: ($sub | tonumber), ipv4: { addresses: [ { address: "auto", nat_1_1_address: "auto" } ] } } } ], metadata: { user_data: $ud }, disk_encryption: "enabled" }')"
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
