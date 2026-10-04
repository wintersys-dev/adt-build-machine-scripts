#!/bin/sh
######################################################################################################
# Description: This script will install ansible
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
	options="-o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y"
elif ( [ "`/bin/grep "^PACKAGEMANAGER:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $NF}'`" = "apt-get" ] )
then
	manager="/usr/bin/apt-get"
	options="-o DPkg::Lock::Timeout=-1 -o Dpkg::Use-Pty=0 -qq -y"
elif ( [ "`/bin/grep "^PACKAGEMANAGER:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $NF}'`" = "nala" ] )
then
	manager="/usr/bin/nala"
	tail_options="-y"
elif ( [ "`/bin/grep "^PACKAGEMANAGER:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $NF}'`" = "aptitude" ] )
then
        manager="/usr/bin/aptitude"
        options="-y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'"
fi

export DEBIAN_FRONTEND=noninteractive 
add_repository_command="/usr/bin/add-apt-repository -y "
install_command="${manager} ${options} install "
update_command="${manager} ${options} update "

if ( [ "${manager}" != "" ] )
then
	if ( [ "${buildos}" = "ubuntu" ] )
	then
    	eval ${update_command}
    	eval ${install_command} software-properties-common
    	eval ${add_repository_command} --yes --update ppa:ansible/ansible
    	eval ${install_command} ansible
	fi

	if ( [ "${buildos}" = "debian" ] )
	then
    	UBUNTU_CODENAME=resolute
    	/usr/bin/wget -O- "https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367" | /usr/bin/gpg --dearmor -o /usr/share/keyrings/ansible-archive-keyring.gpg
    	/bin/echo "deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu ${UBUNTU_CODENAME} main" | sudo /usr/bin/tee /etc/apt/sources.list.d/ansible.list
    	/usr/bin/apt update && /usr/bin/apt install ansible	
  	fi
fi




