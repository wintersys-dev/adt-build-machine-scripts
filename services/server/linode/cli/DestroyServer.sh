#!/bin/sh
###################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will destroy the specified server by ip address
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
###################################################################################
###################################################################################
#set -x

status () {
	/bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
	script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
	/bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

server_ip="${1}"
cloudhost="${2}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`" 
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"

	if ( [ "${server_ip}" != "" ] )
	then
		server_id="`/usr/local/bin/linode-cli linodes list --no-defaults --json | /usr/bin/jq -r '.[] | select (.ipv4[] == "'${server_ip}'").id'`"
		if ( [ "${server_id}" = "" ] )
		then
			server_ip="`${BUILD_HOME}/services/server/GetServerPublicIPAddressByIP.sh ${server_ip} ${cloudhost}`"
			server_id="`/usr/local/bin/linode-cli linodes list --no-defaults --json | /usr/bin/jq -r '.[] | select (.ipv4[] == "'${server_ip}'").id'`"
		fi
		/usr/local/bin/linode-cli linodes shutdown ${server_id}
		/usr/local/bin/linode-cli linodes delete ${server_id}
		status "Destroyed a server with ip address ${server_ip}"
	fi
