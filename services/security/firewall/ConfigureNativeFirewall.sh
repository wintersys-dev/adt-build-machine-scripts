#!/bin/sh
######################################################################################################
# Description: This will configure the native firewall to restrict access by ip address to our infrastructure
# according to what our configuration needs are. Sometimes machines are only accessible through the VPC they
# are in and sometimes they have to be accessible across the internet. The policy is designed to keep access
# to the machines as strict and as limited as possible. 
# Author: Peter Winter
# Date: 17/01/2021
#######################################################################################################
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
#######################################################################################################
#######################################################################################################
#set -x

set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] )
then
        status "Error: 1 argument is required."
        status "Usage: $0 <firewall_name>"
        exit 1
fi

firewall_name="${1}"

ACTIVE_FIREWALLS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh ACTIVE_FIREWALLS`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"


if ( [ "${ACTIVE_FIREWALLS}" = "2" ] || [ "${ACTIVE_FIREWALLS}" = "3" ] )
then

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

	script_path="${BUILD_HOME}/services/security/firewall/${CLOUDHOST}/${orchestration_tool}/ConfigureNativeFirewall.sh"

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

	/bin/echo "`${script_path} ${firewall_name}`"  

	exit_code=$?

	if ( [ ${exit_code} -ne 0 ] )
	then
        status "Error: ConfigureNativeFirewall.sh failed with exit code $exit_code"
        exit $exit_code
	fi
fi


