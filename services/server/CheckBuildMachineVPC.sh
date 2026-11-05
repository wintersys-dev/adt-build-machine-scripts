#!/bin/sh
###################################################################################
# @file        CheckBuildMachineVPC.sh
# @brief       Orchestrates VPC topological validation checks across active cloud hosts.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses environment software configurations to identify 
#              the target cloud architecture landscape, dynamically maps execution 
#              paths to provider-specific validation suites, handles exit states 
#              manually, and monitors underlying subnet boundaries safely.
#
# @param       $1  [Required] The management or public IP address of the target buildmachine.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST state tracking descriptor file.
#              - ${BUILD_HOME}/configuration/software.dat toolkit software configuration registry.
#              - external dependencies: cat, echo, awk, tr
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#              - Isolates runtime subprocess transaction state codes manually within safe bounds.
#
# @exit        0  Success: Target host VPC interface definitions validated cleanly.
# @exit        *  Failure: Runtime path verification error, broken configurations, or bubbling
#                 exit code failures generated directly by the underlying execution script.
##################################################################################
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

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

if [ -z "${1}" ]
then
        status "Error: Build Machine IP address argument is required."
        status "Usage: $0 <buildmachine_ip>" 
        exit 1
fi

buildmachine_ip="${1}"

cloudhost_file="${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST"
if [ ! -f "${cloudhost_file}" ] || [ ! -r "${cloudhost_file}" ]
then
        status "Error: Cannot read active cloud host file at ${cloudhost_file}"
        exit 1
fi

CLOUDHOST="$(/bin/cat "${cloudhost_file}")"

if [ -z "${CLOUDHOST}" ]
then
        status "Error: CLOUDHOST variable is empty."
        exit 1
fi

software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}" 
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/CheckBuildMachineVPC.sh"

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

set +e
"${script_path}" "${buildmachine_ip}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Error: CheckBuildMachineVPC.sh failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0

