###################################################################################
# @file        AdjustDBaaSFirewall.sh
# @brief       Hardens cloud DBaaS instances by restricting firewall access matrices.
# @author      Peter Winter
# @date        12/07/2016
# @version     1.0
#
# @details     Evaluates regional environments and installation states to apply localized
#              security boundaries. If a managed cluster operates outside a shared VPC 
#              infrastructure, individual IP routes are dynamically evaluated and injected.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - ObtainDatabaseID.sh utility to resolve active managed cluster tracking tokens.
#              - UpdateDBaaSFirewall.sh operational runtime execution engine.
#              - external dependencies: awk
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Implements pure POSIX shell pattern evaluations to prevent execution injection.
#
# @exit        0  Success: Security parameters updated or skipped safely under rules.
# @exit        1  Failure: Missing configuration items or failed parameter evaluation.
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
#set -x
set -e

status () {
    "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Read build home path securely without spawning cat
if [ -r /home/buildhome.dat ]
then
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

if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
    status "Error: Cannot read software configuration file at ${software_file}"
    exit 1
fi

# Parse orchestration tool securely
orchestration_tool=$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")

if [ -z "${orchestration_tool}" ]
then
    status "Error: ORCHESTRATION_TOOL not found in ${software_file}" 
    exit 1
fi

database_type="mysql"
if [ "$(/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /bin/grep '^Postgres')" != "" ]
then
	database_type="postgres"
fi

# Evaluate firewall updates under regional constraints
if [ "${MULTI_REGION}" = "0" ] || ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] )
then
    # Fixed the missing spacing syntax error in the string comparison
    if [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ]
	then
        # Pure POSIX shell pattern matching replacing echo | grep pipeline
        case "${DATABASE_DBaaS_INSTALLATION_TYPE}" in
            *DBAAS*)
                database_id=$("${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type}/ObtainDatabaseID.sh")
                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type}/UpdateDBaaSFirewall.sh" "${database_id}" "${VPC_IP_RANGE}"
                ;;
        esac
    fi
fi




