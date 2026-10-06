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
#CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
#BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"

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
install_command="${manager} ${options} install "
update_command="${manager} ${options} update "

if ( [ "${manager}" != "" ] )
then
	if ( [ "${buildos}" = "ubuntu" ] )
	then
	
		if ( [ ! -d ${BUILD_HOME}/runtime/ansible-env ] )
		then
        	/bin/mkdir -p ${BUILD_HOME}/runtime/ansible-env
		fi

		python_version="`python3 --version | /usr/bin/awk '{print $NF}' | cut -d. -f1,2`"

    	eval ${update_command}
		eval ${install_command} python${python_version}-venv ${tail_options}
		eval ${install_command} ansible-core
		
		python3 -m venv ${BUILD_HOME}/runtime/ansible-env
		. ${BUILD_HOME}/runtime/ansible-env/bin/activate
		pip install --upgrade pip

		/usr/bin/wget https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt -O ${BUILD_HOME}/runtime/ansible-env/requirements.txt

		if [ $? -eq 0 ] 
		then
        	cat << 'EOF' > "${BUILD_HOME}/runtime/ansible-env/requirements.txt"
linode_api4>=5.46.1
polling==0.3.2
ansible-specdoc>=0.0.20
EOF
		fi
		pip install --upgrade -r ${BUILD_HOME}/runtime/ansible-env/requirements.txt
	fi

	if ( [ "${buildos}" = "debian" ] )
	then
	
		if ( [ ! -d ${BUILD_HOME}/runtime/ansible-env ] )
		then
        	/bin/mkdir -p ${BUILD_HOME}/runtime/ansible-env
		fi

		python_version="`python3 --version | /usr/bin/awk '{print $NF}' | cut -d. -f1,2`"

    	eval ${update_command}
		eval ${install_command} python${python_version}-venv ${tail_options}
		eval ${install_command} ansible-core
		
		python3 -m venv ${BUILD_HOME}/runtime/ansible-env
		. ${BUILD_HOME}/runtime/ansible-env/bin/activate
		pip install --upgrade pip

		/usr/bin/wget https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt -O ${BUILD_HOME}/runtime/ansible-env/requirements.txt

		if [ $? -eq 0 ] 
		then
        	cat << 'EOF' > "${BUILD_HOME}/runtime/ansible-env/requirements.txt"
linode_api4>=5.46.1
polling==0.3.2
ansible-specdoc>=0.0.20
EOF
		fi
		pip install --upgrade -r ${BUILD_HOME}/runtime/ansible-env/requirements.txt
  	fi
fi




