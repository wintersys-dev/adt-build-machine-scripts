#!/bin/sh
############################################################################
# Author : Peter Winter
# Date   : 13/06/2016
# Description : This script gets a machine's public ip based on its private ip
#############################################################################
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

if ( [ "${1}" = "" ] )
then
    echo "Error: Server type argument is required." >&2
    echo "Usage: $0 <server_type>" >&2
    exit 1
fi

server_ip="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

cloudhost_file="${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST"
if ( [ ! -f "${cloudhost_file}" ] || [ ! -r "${cloudhost_file}" ] )
then
    echo "Error: Cannot read active cloud host file at ${cloudhost_file}" >&2
    exit 1
fi

CLOUDHOST="`/bin/cat "${cloudhost_file}"`"

if ( [ "${CLOUDHOST}" = "" ] )
then
    echo "Error: CLOUDHOST variable is empty." >&2
    exit 1
fi

software_file="${BUILD_HOME}/configuration/software.dat"
if ( [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ] )
then
    echo "Error: Cannot read software configuration file at ${software_file}" >&2
    exit 1
fi

orchestration_tool="`/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}"`"

if ( [ "${orchestration_tool}" ]; then
    echo "Error: ORCHESTRATION_TOOL not found in ${software_tool}" >&2
    exit 1
fi

script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/${orchestration_tool}/GetServerPublicIPAddressByIP.sh "${server_ip}"

if ( [ ! -f "${script_path}" ] )
then
    echo "Error: Script not found at $SCRIPT_PATH" >&2
    exit 1
fi

if ( [ ! -x "${script_path}" ] )
then
    echo "Error: Script at ${script_path} is not executable." >&2
    exit 1
fi

# Execute the script, replacing the current shell process
exec "${script_path}" "${server_ip}"

#ip="${1}"

#BUILD_HOME="`/bin/cat /home/buildhome.dat`"
#CLOUDHOST="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST`"
#orchestration_tool="`/bin/grep "^ORCHESTRATION_TOOL:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $NF}'`"

#${BUILD_HOME}/services/server/${CLOUDHOST}/${orchestration_tool}/GetServerPublicIPAddressByIP.sh "${ip}" 
