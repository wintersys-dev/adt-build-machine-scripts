#!/bin/sh
#########################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description :  This script gets the private ip address of a machine given its unique name
#########################################################################################
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
########################################################################################
########################################################################################
#set -x

server_type="${1}"
cloudhost="${2}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`" 
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"


	linodeids="`/usr/local/bin/linode-cli linodes list --no-defaults --json | /usr/bin/jq -r '.[] | select (.label | contains("'${server_type}'")).id'`"

	privateips=""
	for linodeid in ${linodeids}
	do
		privateip="`/usr/local/bin/linode-cli linodes ips-list ${linodeid} --no-defaults --json | /usr/bin/jq -r '.[].ipv4.vpc[].address' 2>/dev/null`"		
		privateips=${privateips}" ${privateip}"
	done
	/bin/echo ${privateips}
