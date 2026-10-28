#!/bin/sh
###################################################################################
# @file        ListServerIDs.sh
# @brief       Resolves active vendor properties and routes queries to list server IDs by type.
# @author      Peter Winter
# @date        13/07/2021
# @version     1.0
#
# @details     This script serves as a high-level wrapper layout within the framework. 
#              It checks core runtime environment metadata to discover the active cloud 
#              host platform and automated orchestration engine, validates target script 
#              permissions, forwards the machine target label, and prints the isolated 
#              resource identifiers to standard output.
#
# @param       $1  [Required] The targeted server architecture type or category classification label.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
# @env         CLOUDHOST           The active virtual infrastructure hosting provider.
# @env         ORCHESTRATION_TOOL  The underlying automation mechanism used to interact with cloud APIs.
#
# @exit        0  Success: Target handoff complete and server engine IDs fetched successfully.
# @exit        1  Failure: Missing positional parameters, unreadable environment configurations, 
#                 or exceptions encountered executing downstream provider tools.
#
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
###################################################################################
###################################################################################
#set -x
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] )
then
    status "Error: Server type argument is required."
    status "Usage: $0 <server_type>"
    exit 1
fi

server_type="${1}"

cloudhost_file="${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST"
if ( [ ! -f "${cloudhost_file}" ] || [ ! -r "${cloudhost_file}" ] )
then
    status "Error: Cannot read active cloud host file at ${cloudhost_file}"
    exit 1
fi

CLOUDHOST="`/bin/cat "${cloudhost_file}"`"

if ( [ "${CLOUDHOST}" = "" ] )
then
    status "Error: CLOUDHOST variable is empty." 
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

script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/${orchestration_tool}/ListServerIDs.sh"

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

result="`"${script_path}" "${server_type}" | /bin/grep -v "Error"`"

exit_code=$?

if ( [ ${exit_code} -ne 0 ] )
then
        status "Error: ListServerIDs.sh failed with exit code $exit_code"
        exit $exit_code
fi

if ( [ "${result}" != "" ] )
then
        echo ${result}
fi









