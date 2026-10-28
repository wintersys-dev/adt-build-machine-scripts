#!/bin/sh
set -x
set -e

BUILD_HOME="$(cat /home/buildhome.dat)"

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

emergency_password="${1}"
region="${2}"
image="${3}"
server_size="${4}"
server_name="${5}"
subnet_id="${6}"
user_data="${7}"
firewall_id="${8}"
snapshot_id="${9}"

# Normalize inputs
if ( [ "${snapshot_id}" != "" ] )
then
        image="${snapshot_id}"
fi

# Fetch system configurations
VPC_IP_RANGE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)"
VPC_NAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_NAME)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if ( [ "`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/vpcs" | /usr/bin/jq -r '.data[] | select(.label == "'${VPC_NAME}'").id'`" = "" ] )
then
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST "https://api.linode.com/v4/vpcs" -H "Content-Type: application/json" -d '{ "label": "'"${VPC_NAME}"'", "region": "'"${REGION}"'", "subnets": [ { "label": "adt-subnet", "ipv4": "'"${VPC_IP_RANGE}"'" } ] }'
fi

vpc_id="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/vpcs" | /usr/bin/jq -r '.data[] | select(.label == "'${VPC_NAME}'").id'`"
subnet_id="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/vpcs/${vpc_id}/subnets" | /usr/bin/jq -r '.data[] | select(.label == "adt-subnet").id'`"

# Temporary disable set -e to handle the error manually
set +e

# Run curl without -f, capturing the HTTP status code on the last line of the output
raw_output=$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST "https://api.linode.com/v4/linode/instances" \
        -H "Content-Type: application/json" \
        -d '{ "root_pass": "'"${emergency_password}"'", "region": "'"${region}"'", "image": "'"${image}"'", "type": "'"${server_size}"'", "label": "'"${server_name}"'", "interface_generation": "linode", "interfaces": [ {  "firewall_id": '"${firewall_id}"', "vpc": { "subnet_id": '"${subnet_id}"', "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ], "metadata": { "user_data": "'"${user_data}"'" }, "disk_encryption": "enabled" }' \
        -w "\n%{http_code}")

# Restore strict error checking
set -e

# Split the JSON response body from the HTTP code (the last line)
api_response=$(/bin/echo "${raw_output}" | /usr/bin/sed '$d')
http_code=$(/bin/echo "${raw_output}" | /usr/bin/tail -n 1)

# Check if the HTTP status code indicates a failure (anything that is not 2XX)
if [ "${http_code}" -lt 200 ] || [ "${http_code}" -ge 300 ]; then
        /bin/echo "Error: Linode instance deployment failed with HTTP status ${http_code}." >&2

    # Extract the exact reason from Linode's JSON response
    error_message=$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[].reason' 2>/dev/null || /bin/echo "Unknown API error: ${api_response}")
    /bin/echo "Reason: ${error_message}" >&2
    exit 1
fi
