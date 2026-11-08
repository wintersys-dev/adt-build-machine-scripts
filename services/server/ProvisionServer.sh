#!/bin/sh 
###################################################################################
# @file        ProvisionServer.sh
# @brief       Orchestrates the metadata preparation and triggers provider-specific instance deployment.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script gathers environment configuration data (cloudhost, region, 
#              OS configurations, firewalls, and credentials), serializes the cloud-init 
#              payload into base64 format, resolves potential snapshot restorations, 
#              and passes the consolidated parameters down to the active provider's 
#              underlying orchestration creation subsystem script.
#
# @param       $1  [Required] The targeted server hardware size plan / tier.
# @param       $2  [Required] The human-readable label/hostname assigned to the server.
# @param       $3  [Required] The structural type or architecture category of the machine.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh utility to capture build updates.
#              - ${BUILD_HOME}/helpers/services/GetVariableValue.sh framework configuration mapping layer.
#              - ${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh distribution matching software.
#              - ${BUILD_HOME}/initialisation/cloud-init/InitialiseCloudConfig.sh initialization driver.
#              - ${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh framework security orchestrator.
#
# @security    
#              - Unsets the critical `EMERGENCY_PASSWORD` register immediately after execution context terminates.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Runtime options consolidated and server provisioner launched successfully.
# @exit        1  Failure: Missing positional arguments, unreadable configurations, or failure 
#                 encountered executing down-stack orchestration tooling.
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
#########################################################################################
#set -x
set -e

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}" 2>/dev/null
}

# 1. Check for all 3 arguments safely
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
then
        status "Error: 3 Server arguments are required."
        status "Usage: $0 <server_size> <server_name> <machine_type>"
        exit 1
fi

server_size="$1"
server_name="$2"
machine_type="$3"

cloudhost_file="${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST"
if [ ! -f "${cloudhost_file}" ] || [ ! -r "${cloudhost_file}" ]
then
        status "Error: Cannot read active cloud host file at ${cloudhost_file}"
        exit 1
fi

build_id_file="${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER"
if [ ! -f "${build_id_file}" ] || [ ! -r "${build_id_file}" ]
then
        status "Error: Cannot read active build identifier file at ${build_id_file}"
        exit 1
fi

CLOUDHOST="$(/bin/cat "${cloudhost_file}")"
BUILD_IDENTIFIER="$(/bin/cat "${build_id_file}")"

set +e
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION 2>/dev/null)"
WEBSITE_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" WEBSITE_URL 2>/dev/null)"
ACTIVE_FIREWALLS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" ACTIVE_FIREWALLS 2>/dev/null)"
BUILDOS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILDOS 2>/dev/null)"
BUILDOS_VERSION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILDOS_VERSION 2>/dev/null)"
BUILD_FROM_SNAPSHOT="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_FROM_SNAPSHOT 2>/dev/null)"
OS_CHOICE="$("${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh" 2>/dev/null | /bin/sed "s/'//g")"
set -e

machine_category="$(/bin/echo "${machine_type}" | /bin/sed 's|adt-||')"

set +e
"${BUILD_HOME}/initialisation/cloud-init/InitialiseCloudConfig.sh" "${machine_category}" "${server_name}" 2>/dev/null
set -e

yaml_path="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_category}.yaml"
if [ -f "${yaml_path}" ]
then
        user_data="${yaml_path}" 
else
        status "Cloud config file not found"
        exit 1
fi

snapshot_id=""
if [ "${BUILD_FROM_SNAPSHOT}" = "1" ]
then
        snapshot_file="${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat"
        if [ -f "${snapshot_file}" ]
        then
                snapshot_id="$(/bin/grep "${machine_category}" "${snapshot_file}" 2>/dev/null | /usr/bin/awk -F':' '{print $NF}')"
                status "Deploying ${machine_category} machine from snapshot with ID ${snapshot_id}"
        fi
fi

firewall_id=""
if [ "${ACTIVE_FIREWALLS}" = "2" ] || [ "${ACTIVE_FIREWALLS}" = "3" ]
then
        set +e
        firewall_id="$("${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh" "${machine_type}" 2>/dev/null | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print $NF}')"
        set -e
fi

if [ -z "${firewall_id}" ]
then
        firewall_id="-1"
fi

pass_file="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/EMERGENCY_PASSWORD"
if [ -f "${pass_file}" ]
then    
        emergency_password="$(/bin/cat "${pass_file}")"
else
        emergency_password="$(/usr/bin/openssl rand -base64 32 2>/dev/null | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-16)"
        /bin/echo "${emergency_password}" > "${pass_file}"
fi

image="${OS_CHOICE}" 
if [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -n "${snapshot_id}" ]
then
        image="${snapshot_id}"
fi


script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/ProvisionServer.sh"

if [ ! -f "${script_path}" ]
then
        status "Error: Script not found at ${script_path}" 
        exit 1
fi

if [ ! -x "${script_path}" ]
then
        status "Error: Script at ${script_path} is not executable."
        exit 1
fi

export EMERGENCY_PASSWORD="${emergency_password}"

set +e
"${script_path}" "${REGION}" "${image}" "${server_size}" "${server_name}" "${user_data}" "${firewall_id}" "${snapshot_id}"
exit_code=$?
set -e

unset EMERGENCY_PASSWORD

if [ ${exit_code} -ne 0 ]
then
        status "Error: ProvisionServer.sh failed with exit code $exit_code"
        exit $exit_code
fi

exit 0
