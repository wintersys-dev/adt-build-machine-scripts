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
#set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`" 
BUILD_IDENTIFIER="`/bin/cat ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER`"

ip="${1}"
cloudhost="${2}"


	#vpc_id="`/usr/bin/vultr vpc2 list -o json | /usr/bin/jq -r '.vpcs[] | select (.description == "adt-vpc").id'`"
	#id="`/usr/bin/vultr vpc2 nodes list ${vpc_id} -o json | /usr/bin/jq -r '.nodes[] | select (.ip_address == "'${ip}'").id'`"
	#/usr/bin/vultr instance get ${id} -o json | /usr/bin/jq -r '.instance.main_ip'
	ids="`/usr/bin/vultr instance list -o json | /usr/bin/jq -r '.instances[] | .id'`"
	for id in ${ids}
	do
		if ( [ "`/usr/bin/vultr instance ipv4 list ${id} -o json | /usr/bin/jq -r '.ipv4s[] | select (.ip == "'${ip}'")'`" != "" ] )
		then
			machine_id="${id}"
		fi
	done
	/usr/bin/vultr instance list ${machine_id} -o json | /usr/bin/jq -r '.instances[].main_ip'
