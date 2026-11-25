#!/bin/sh
#: Name:        AdjustDBaaSFirewall.sh
#: Purpose:     Hardens cloud DBaaS instances by restricting firewall access matrices.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       AdjustDBaaSFirewall.sh
#:              AdjustDBaaSFirewall.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads deployment topology and DBaaS variables via GetVariableValue.sh.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - obtain_dbaas_id.sh
#:   - update_dbaas_firewall.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - External binaries: cat, echo, grep, cut, awk
#:
#: Exit Codes:
#:   0          Security parameters updated or skipped safely under regional rules
#:   1          Missing configuration files, unreadable state, or failed parameter lookup
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

# Retrieve regional topology and database configuration values from active deployment context
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
VPC_IP_RANGE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)"
MULTI_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" MULTI_REGION)"
PRIMARY_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" PRIMARY_REGION)"
DATABASE_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_INSTALLATION_TYPE)"
DATABASE_DBaaS_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_DBaaS_INSTALLATION_TYPE)"

# Verify that the core software configuration file exists and is readable
software_file="${BUILD_HOME}/configuration/software.dat"

if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

# Extract the active orchestration tool (cli or api) from software.dat
orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

# Apply DBaaS firewall allow-list updates only on single-region or primary multi-region builds
if [ "${MULTI_REGION}" = "0" ] || ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] )
then
        if [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ]
        then
                case "${DATABASE_DBaaS_INSTALLATION_TYPE}" in
                        *DBAAS*)
                                # Resolve the managed DBaaS cluster ID and update its VPC IP range allow-list
                                database_id="$("${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/obtain_dbaas_id.sh")"
                                if [ ! -n "${database_id}" ] 
                                then
                                        status "Error: database_id not set"
                                        exit 1
                                fi
                                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/update_dbaas_firewall.sh" "${database_id}" "${VPC_IP_RANGE}"
                                ;;
                esac
        fi
fi

exit 0





