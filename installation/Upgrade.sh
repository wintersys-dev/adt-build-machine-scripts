#!/bin/sh
######################################################################################################
# Description: This script will perform a software upgrade
# Author: Peter Winter
# Date: 17/01/2017
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

if ( [ "${1}" != "" ] )
then
	buildos="${1}"
fi

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

manager=""
options=""
tail_options=""
if ( [ "`/bin/grep "^PACKAGEMANAGER:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $NF}'`" = "apt" ] )
then
	manager="/usr/bin/apt"
	options="-o DPkg::Lock::Timeout=-1 -qq -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y --allow-downgrades --allow-remove-essential --allow-change-held-packages"
elif ( [ "`/bin/grep "^PACKAGEMANAGER:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $NF}'`" = "apt-get" ] )
then
	manager="/usr/bin/apt-get"
	options="-o DPkg::Lock::Timeout=-1 -qq -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y --allow-downgrades --allow-remove-essential --allow-change-held-packages"
elif ( [ "`/bin/grep "^PACKAGEMANAGER:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $NF}'`" = "nala" ] )
then
	manager="/usr/bin/nala"
	tail_options="-y"
fi

export DEBIAN_FRONTEND=noninteractive 
upgrade_command="${manager} ${options} upgrade " 

if ( [ "${manager}" != "" ] )
then
	if ( [ "${buildos}" = "ubuntu" ] )
	then
		eval ${upgrade_command}
	fi

	if ( [ "${buildos}" = "debian" ] )
	then
		eval ${upgrade_command} 
	fi
fi


