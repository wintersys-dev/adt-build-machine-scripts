#!/bin/sh
########################################################################################
# Description: This script will create a zone with your DNS provider. 
# Author: Peter Winter
# Date: 02/01/2017
########################################################################################
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
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
domain_url="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"

DNS_USERNAME="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME)"     
TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_SECURITY_KEY)"
export LINODE_CLI_TOKEN="${TOKEN}"
                
if ( [ "$(/usr/local/bin/linode-cli domains list --domain ${domain_url} --json | jq '.[].id')" = "" ] )
then
        /usr/local/bin/linode-cli domains create --type master --domain ${domain_url} --soa_email ${DNS_USERNAME} --no-defaults
fi

if ( [ $? != "0" ] )
then
        status "Failed to create zone for domain ${domain_url}"
        unset LINODE_CLI_TOKEN
        exit  1
fi
unset LINODE_CLI_TOKEN
