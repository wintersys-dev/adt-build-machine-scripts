#!/bin/sh
# Strict error handling for POSIX shell
set -e

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

emergency_password="${1}"
region="${2}"
image="${3}"
server_size="${4}"
server_name="${5}"
subnet_id="${6}"
user_data="${7}"
firewall_active="${8}"
snapshot_id="${9}"

if ( [ "${firewall_active}" = "none" ] )
then
    firewall_active=""
fi

if ( [ "${snapshot_id}" = "none" ] )
then
    snapshot_id=""
else
    image="${snapshot_id}"
fi

#BUILD_FROM_SNAPSHOT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_FROM_SNAPSHOT`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
VPC_NAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_NAME`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
#BUILDOS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS`"
#BUILDOS_VERSION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS_VERSION`"
#OS_CHOICE="`${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh "linode" "${BUILDOS}" "${BUILDOS_VERSION}" | /bin/sed "s/'//g"`"


if ( [ "`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/vpcs" | /usr/bin/jq -r '.data[] | select(.label == "'${VPC_NAME}'").id'`" = "" ] )
then
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST "https://api.linode.com/v4/vpcs" -H "Content-Type: application/json" -d '{ "label": "'"${VPC_NAME}"'", "region": "'"${region}"'", "subnets": [ { "label": "adt-subnet", "ipv4": "'"${VPC_IP_RANGE}"'" } ] }'
fi

vpc_id="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/vpcs" | /usr/bin/jq -r '.data[] | select(.label == "'${VPC_NAME}'").id'`"
subnet_id="`/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/vpcs/${vpc_id}/subnets" | /usr/bin/jq -r '.data[] | select(.label == "adt-subnet").id'`"

#image="${OS_CHOICE}" 
#if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ "${snapshot_id}" != "" ] )
#then
#        image="${snapshot_id}"
#fi

#user_data="${cloud_config}"

/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST "https://api.linode.com/v4/linode/instances" -H "Content-Type: application/json" -d '{ "root_pass": "'"${emergency_password}"'", "region": "'"${REGION}"'", "image": "'"${image}"'", "type": "'"${server_size}"'", "label": "'"${server_name}"'", "interface_generation": "linode", "interfaces": [ {  '"${firewall_active}"' "vpc": { "subnet_id": '"${subnet_id}"', "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ], "metadata": { "user_data": "'"${user_data}"'" }, "disk_encryption": "enabled" }'
if ( [ "$?" != "0" ] )
then
        exit 1
fi
