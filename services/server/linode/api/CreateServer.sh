#!/bin/sh
set -e

BUILD_HOME="$(cat /home/buildhome.dat)"

emergency_password="${1}"
region="${2}"
image="${3}"
server_size="${4}"
server_name="${5}"
subnet_id="${6}"
user_data="${7}"
firewall_active="${8}"
snapshot_id="${9}"

# Normalize inputs
[ "${firewall_active}" = "none" ] && firewall_active=""
if [ "${snapshot_id}" = "none" ] || [ -z "${snapshot_id}" ]; then
    snapshot_id=""
else
    image="${snapshot_id}"
fi

# Fetch system configurations
VPC_IP_RANGE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)"
VPC_NAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_NAME)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

HEADER="Authorization: Bearer ${TOKEN}"

# Ensure VPC Exists
vpc_id="$(curl -s -H "${HEADER}" "https://api.linode.com/v4/vpcs" | jq -r --arg name "$VPC_NAME" '.data[] | select(.label == $name).id')"

if [ -z "${vpc_id}" ]; then
    vpc_payload="$(jq -n --arg lbl "$VPC_NAME" --arg reg "$region" --arg ip "$VPC_IP_RANGE" '{label: $lbl, region: $reg, subnets: [{label: "adt-subnet", ipv4: $ip}]}')"
    
    vpc_id="$(curl -s -X POST "https://api.linode.com/v4/vpcs" -H "${HEADER}" -H "Content-Type: application/json" -d "${vpc_payload}" | jq -r '.id')"
fi

# Get Subnet ID
subnet_id="$(curl -s -H "${HEADER}" "https://linode.com/${vpc_id}/subnets" | jq -r '.data[] | select(.label == "adt-subnet").id')"

# Build safely escaped Server Payload
instance_payload="$(jq -n \
    --arg pass "$emergency_password" \
    --arg reg "$region" \
    --arg img "$image" \
    --arg type "$server_size" \
    --arg lbl "$server_name" \
    --arg sub "$subnet_id" \
    --arg ud "$user_data" \
    '{
        root_pass: $pass, region: $reg, image: $img, type: $type, label: $lbl,
        interface_generation: "linode",
        interfaces: [{ vpc: { subnet_id: ($sub | tonumber), ipv4: { addresses: [{ address: "auto", nat_1_1_address: "auto" }] } } }],
        metadata: { user_data: $ud },
        disk_encryption: "enabled"
    }')"

# Create Linode Instance
curl -f -s -X POST "https://linode.com" \
    -H "${HEADER}" \
    -H "Content-Type: application/json" \
    -d "${instance_payload}"
