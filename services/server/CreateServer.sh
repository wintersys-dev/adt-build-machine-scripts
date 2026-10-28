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
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

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
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"
WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_URL`"
ACTIVE_FIREWALL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ACTIVE_FIREWALLS`"
BUILDOS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS`"
BUILDOS_VERSION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS_VERSION`"
BUILD_FROM_SNAPSHOT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_FROM_SNAPSHOT`"
OS_CHOICE="`${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh ${CLOUDHOST} ${BUILDOS} ${BUILDOS_VERSION} | /bin/sed "s/'//g"`"

machine_category="`/bin/echo ${machine_type} | /bin/sed 's|adt-||'`"
${BUILD_HOME}/initialisation/cloud-init/InitialiseCloudConfig.sh "${machine_category}" "${server_name}"

if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_category}.yaml ] )
then
        cloud_config="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_category}.yaml | /usr/bin/base64 -w 0`" 
else
        status "Cloud config file not found"
        exit 1
fi

snapshot_id=""
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat ] )
then
        snapshot_id="`/bin/grep ${machine_category} ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat | /usr/bin/awk -F':' '{print $NF}'`"
        status "Deploying ${machine_category} machine from snapshot with ID ${snapshot_id}"
fi

firewall_id="`${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh "${machine_type}" | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print  $NF}'`"

if ( [ "${firewall_id}" = "" ] )
then
        firewall_id="-1"
fi

if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD ] )
then    
        emergency_password="`/bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD`"
else
        emergency_password="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16`"
        /bin/echo "${emergency_password}" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD
fi

image="${OS_CHOICE}" 
if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] )
then
        image="${snapshot_id}"
fi

user_data="${cloud_config}"

cloudhost_file="${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST"
if ( [ ! -f "${cloudhost_file}" ] || [ ! -r "${cloudhost_file}" ] )
then
        status "Error: Cannot read active cloud host file at ${cloudhost_file}"
        exit 1
fi

software_file="${BUILD_HOME}/configuration/software.dat"
if ( [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ] )
then
        status "Error: Cannot read software configuration file at ${software_file}" 
        exit 1
fi

orchestration_tool="`/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}"`"

if ( [ "${orchestration_tool}" = "" ] )
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_tool}"
        exit 1
fi

script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/${orchestration_tool}/CreateServer.sh"

if ( [ ! -f "${script_path}" ] )
then
        status "Error: Script not found at ${script_path}" 
        exit 1
fi

if ( [ ! -x "${script_path}" ] )
then
        status "Error: Script at ${script_path} is not executable."
        exit 1
fi

"${script_path}" "${emergency_password}" "${REGION}" "${image}" "${server_size}" "${server_name}" "${subnet_id}" "${user_data}" "${firewall_id}" "${snapshot_id}"

exit_code=$?

if ( [ ${exit_code} -ne 0 ] )
then
        status "Error: GetServerName.sh failed with exit code $exit_code"
        exit $exit_code
fi

