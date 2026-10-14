#!/bin/sh
###################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will spin up a new server of the size, region and os
# specified  on the hosting provider, cloudhost, of choice.
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
####################################################################################
####################################################################################
set -e

#set -x

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ]  )
then
        status "Error: 3 Server arguments are required."
        status "Usage: $0 <server_type>"
        exit 1
fi

server_size="${1}"
server_name="${2}"
machine_type="${3}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"

BUILDOS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS`"
BUILDOS_VERSION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS_VERSION`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
VPC_NAME="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_NAME`"
ACTIVE_FIREWALL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ACTIVE_FIREWALLS`"
ALGORITHM="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ALGORITHM`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
BUILD_FROM_SNAPSHOT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_FROM_SNAPSHOT`"
OS_CHOICE="`${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh ${CLOUDHOST} ${BUILDOS} ${BUILDOS_VERSION} | /bin/sed "s/'//g"`"

if ( [ "${machine_type}" = "adt-autoscaler" ] )
then
        if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml ] )
        then
                server_name_match="`/bin/grep "^hostname: " ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml | /usr/bin/awk '{print $NF}'`"
                /bin/sed -i "s/XXXXAUTOSCALER_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml
                /bin/sed -i "s/${server_name_match}/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml
                cloud_config="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/autoscaler.yaml | /usr/bin/base64 -w 0`"
        fi

        if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
        then
                snapshot_id="`/bin/grep autoscaler ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
                status "Deploying autoscaler machine from snapshot with ID ${snapshot_id}"
        fi
elif ( [ "${machine_type}" = "adt-webserver" ] )
then
        if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml ] )
        then
                server_name_match="`/bin/echo ${server_name} | /usr/bin/awk -F'-' 'NF{NF--};1' | /bin/sed 's/ /-/g'`"
                /bin/sed -i "s/XXXXWEBSERVER_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml
                /bin/sed -i "s/${server_name_match}.*$/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml
                cloud_config="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/webserver.yaml | /usr/bin/base64 -w 0`"    
        fi

        if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
        then
                snapshot_id="`/bin/grep webserver ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
                status "Deploying webserver machine from snapshot with ID ${snapshot_id}"
                ${BUILD_HOME}/helpers/services/SetVariableValue.sh SNAPSHOT_ID=${snapshot_id}
        fi
elif ( [ "${machine_type}" = "adt-database" ] )
then
        if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/database.yaml ] )
        then
                /bin/sed -i "s/XXXXDATABASE_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/database.yaml
                cloud_config="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/database.yaml | /usr/bin/base64 -w 0`"        
        fi

        if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
        then
                snapshot_id="`/bin/grep database ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
                status "Deploying database machine from snapshot with ID ${snapshot_id}"
        fi
elif ( [ "${machine_type}" = "adt-authenticator" ] )
then
        if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml ] )
        then
                server_name_match="`/bin/grep "^hostname: " ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml | /usr/bin/awk '{print $NF'`"
                /bin/sed -i "s/XXXXAUTHENTICATOR_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml
                /bin/sed -i "s/${server_name_match}/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml
                cloud_config="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/authenticator.yaml | /usr/bin/base64 -w 0`"        
        fi

        if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
        then
                snapshot_id="`/bin/grep authenticator ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
                status "Deploying authenticator machine from snapshot with ID ${snapshot_id}"
        fi
elif ( [ "${machine_type}" = "adt-reverseproxy" ] )
then

        if ( [ -f  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml ] )
        then            
                server_name_match="`/bin/grep "^hostname: " ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml | /usr/bin/awk '{print $NF}'`" 
                /bin/sed -i "s/XXXXREVERSEPROXY_HOSTNAMEXXXX/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml
                /bin/sed -i "s/${server_name_match}/${server_name}/g" ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml
                cloud_config="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/reverseproxy.yaml | /usr/bin/base64 -w 0`"         
        fi

        if (  [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
        then
                snapshot_id="`/bin/grep reverseproxy ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
                status "Deploying reverse proxy machine from snapshot with ID ${snapshot_id}"
        fi
fi

firewall_id="`${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh "${machine_type}" | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print  $NF}'`"

firewall_active=""
if ( [ "${ACTIVE_FIREWALL}" = "2" ] || [ "${ACTIVE_FIREWALL}" = "3" ] )
then
        #       firewall_active="\"firewall_id\": ${firewall_id}, " 
        firewall_active='"firewall_id": '${firewall_id}', '
fi

if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD ] )
then    
        emergency_password="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD`"
else
        emergency_password="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16`"
        /bin/echo "${emergency_password}" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD
fi

if ( [ "`curl -H "Authorization: Bearer $TOKEN" -s "https://api.linode.com/v4/vpcs" | /usr/bin/jq -r '.data[] | select(.label == "'${VPC_NAME}'").id'`" = "" ] )
then
        curl -X POST "https://api.linode.com/v4/vpcs" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{ "label": "'"${VPC_NAME}"'", "region": "'"${REGION}"'", "subnets": [ { "label": "adt-subnet", "ipv4": "'"${VPC_IP_RANGE}"'" } ] }'
fi

vpc_id="`curl -H "Authorization: Bearer $TOKEN" -s "https://api.linode.com/v4/vpcs" | /usr/bin/jq -r '.data[] | select(.label == "'${VPC_NAME}'").id'`"
subnet_id="`curl -H "Authorization: Bearer $TOKEN" -s "https://api.linode.com/v4/vpcs/${vpc_id}/subnets" | /usr/bin/jq -r '.data[] | select(.label == "adt-subnet").id'`"

image="${OS_CHOICE}" 
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] )
then
        image="${snapshot_id}"
fi

user_data="${cloud_config}"


/usr/bin/curl -X POST "https://api.linode.com/v4/linode/instances" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{ "root_pass": "'"${emergency_password}"'", "region": "'"${REGION}"'", "image": "'"${image}"'", "type": "'"${server_size}"'", "label": "'"${server_name}"'", "interface_generation": "linode", "interfaces": [ {  '"${firewall_active}"' "vpc": { "subnet_id": '"${subnet_id}"', "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ], "metadata": { "user_data": "'"${user_data}"'" }, "disk_encryption": "enabled" }'


#if ( [ "${ACTIVE_FIREWALL}" = "2" ] || [ "${ACTIVE_FIREWALL}" = "3" ] )
#then
#        /usr/bin/curl -X POST "https://api.linode.com/v4/linode/instances" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{ "root_pass": "'"${emergency_password}"'", "region": "'"${REGION}"'", "image": "'"${image}"'", "type": "'"${server_size}"'", "label": "'"${server_name}"'", "interface_generation": "linode", "interfaces": [ { "firewall_id": '"${firewall_id}"', "vpc": { "subnet_id": '"${subnet_id}"', "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ], "metadata": { "user_data": "'"${user_data}"'" }, "disk_encryption": "enabled" }'
#else
#        /usr/bin/curl -X POST "https://api.linode.com/v4/linode/instances" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{ "root_pass": "'"${emergency_password}"'", "region": "'"${REGION}"'", "image": "'"${image}"'", "type": "'"${server_size}"'", "label": "'"${server_name}"'", "interface_generation": "linode", "interfaces": [ { "vpc": { "subnet_id": '"${subnet_id}"', "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ], "metadata": { "user_data": "'"${user_data}"'" }, "disk_encryption": "enabled" }'
#fi
if ( [ "$?" != "0" ] )
then
        exit 1
fi
