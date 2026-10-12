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


ip="${1}"


	zone="`/bin/cat ${BUILD_HOME}/runtime/${cloudhost}/${BUILD_IDENTIFIER}/CURRENTREGION`"
	server_name="`/usr/bin/exo compute private-network show adt_private_net_${zone} --zone ${zone} -O json | /usr/bin/jq -r '.leases[] | select(.ip_address=="'${ip}'") | .instance'`"
	/usr/bin/exo compute instance list --zone ${zone} -O json | /usr/bin/jq -r '.[] | select (.name =="'${server_name}'").ip_address' 
