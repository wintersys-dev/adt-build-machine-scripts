#!/bin/sh 
###################################################################################
# @file        NumberOfServers.sh
# @brief       Resolves active vendor properties and routes queries to count instances by type.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script serves as a high-level wrapper layout within the framework. 
#              It reads global configuration files to determine the current cloud host 
#              platform and automated orchestration engine, validates target execution 
#              pathways, and delegates the server type classification argument down to 
#              the underlying provider counting module.
#
# @param       $1  [Required] The targeted server architecture type or category classification label.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active application root path.
#              - ${HOME}/helpers/services/LogStatusMessages.sh utility to capture build updates.
#
# @security    
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target handoff complete and server count calculated successfully.
# @exit        1  Failure: Missing positional parameters, unreadable environment configurations, 
#                 or exceptions encountered executing downstream provider tools.
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

# Sourced application root tracking pathway string
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

status () {
    ${HOME}/helpers/services/LogStatusMessages.sh "${1}" 2>/dev/null
}

# 1. Check for the required argument safely
if [ -z "$1" ]
then
    status "Error: Server type argument is required." 
    status "Usage: $0 <server_type>" 
    exit 1
fi

server_type="$1"

cloudhost_file="${HOME}/runtime/ACTIVE_CLOUDHOST"
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

software_file="${HOME}/configuration/software.dat"
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

script_path="${HOME}/services/server/${CLOUDHOST}/${orchestration_tool}/NumberOfServers.sh"

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
"${script_path}" "${server_type}"
exit_code=$?
set -e

if [ ${exit_code} -ne 0 ]
then
    status "Error: NumberOfServers.sh failed with exit code $exit_code"
    exit $exit_code
fi

exit 0
