#!/bin/sh 
###################################################################################
# @file        TerminateServer.sh
# @brief       Resolves runtime configurations and triggers provider-specific instance termination.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script acts as the entry orchestrator for system decommissioning.
#              It reads global framework variables to determine the active cloud host
#              and deployment toolchain, validates the targeted execution pathways,
#              and hands off the target IPv4 address argument to the underlying
#              provider infrastructure demolition script.
#
# @param       $1  [Required] The target public IPv4 address of the instance to destroy.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - ${BUILD_HOME}/helpers/services/LogStatusMessages.sh utility to capture build updates.
#
# @security    
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target handoff complete and server terminated successfully.
# @exit        1  Failure: Missing parameters, missing host state metadata, or errors
#                 encountered during downstream platform cleanup tasks.
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

# 1. Check for the required argument safely
if [ -z "$1" ]
then
    status "Error: Server IP address argument is required." 
    status "Usage: $0 <server_ip>" 
    exit 1
fi

server_ip="$1"

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

script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/TerminateServer.sh"

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
"${script_path}" "${server_ip}"
exit_code=$?
set -e

if [ ${exit_code} -ne 0 ]
then
    status "Error: TerminateServer.sh failed with exit code $exit_code"
    exit $exit_code
fi

exit 0
