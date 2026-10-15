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
set -x

set -e

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}


if ( [ "${1}" = "" ] )
then
        status "Error: 1 argument is required.."
        status "Usage: $0 <zone_name>"
        exit 1
fi

zone_name="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE`"

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

if ( [ ! -d ${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool} ] )
then
        orchestration_tool="api"
fi

script_path="${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}/GetZoneID.sh"

if ( [ -f "${script_path}" ] && [ -x "${script_path}" ] )
then
        "${script_path}" "${zone_name}"

        exit_code=$?

        if ( [ ${exit_code} -ne 0 ] )
        then
                status "Error: CreateServer.sh failed with exit code $exit_code"
                exit $exit_code
        fi
fi
