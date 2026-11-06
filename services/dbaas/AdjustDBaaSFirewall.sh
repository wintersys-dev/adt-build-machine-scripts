#!/bin/sh
########################################################################################
# Author: Peter Winter
# Date  : 12/07/2016
# Description: If you are deploying a DBaaS system, this will tighten the firewalling system
# so that the databases are only accessible by ip addresses that we are using. 
# This is applied towards the end of the build process
# It depends on whether the DBaaS service is run in the same VPC as our server machines.
# If it is then access is available through the VPC if it isn't then individual IP addresses
# have to be granted access. That is why you see some providers with processing needed here
# when the DBaaS isn't running in the same VPC as the servers are. 
########################################################################################
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
#########################################################################################
#########################################################################################
#set -x
set -e

status () {
    "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Read build home path securely without spawning cat
if [ -r /home/buildhome.dat ]; then
    read -r BUILD_HOME < /home/buildhome.dat
else
    echo "Error: Cannot read /home/buildhome.dat" >&2
    exit 1
fi

# Fetch configuration values using modern command substitution
CLOUDHOST=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)
VPC_IP_RANGE=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)
MULTI_REGION=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" MULTI_REGION)
PRIMARY_REGION=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" PRIMARY_REGION)
DATABASE_INSTALLATION_TYPE=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_INSTALLATION_TYPE)
DATABASE_DBaaS_INSTALLATION_TYPE=$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_DBaaS_INSTALLATION_TYPE)

software_file="${BUILD_HOME}/configuration/software.dat"

if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]; then
    status "Error: Cannot read software configuration file at ${software_file}"
    exit 1
fi

# Parse orchestration tool securely
orchestration_tool=$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")

if [ -z "${orchestration_tool}" ]; then
    status "Error: ORCHESTRATION_TOOL not found in ${software_file}" 
    exit 1
fi

# Evaluate firewall updates under regional constraints
if [ "${MULTI_REGION}" = "0" ] || { [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ]
then
    # Fixed the missing spacing syntax error in the string comparison
    if [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ]
	then
        # Pure POSIX shell pattern matching replacing echo | grep pipeline
        case "${DATABASE_DBaaS_INSTALLATION_TYPE}" in
            *DBAAS*)
                database_id=$("${BUILD_HOME}/services/dbaas/linode/api/mysql/ObtainDatabaseID.sh")
                "${BUILD_HOME}/services/dbaas/linode/api/mysql/UpdateDBaaSFirewall.sh" "${database_id}" "${VPC_IP_RANGE}"
                ;;
        esac
    fi
fi




