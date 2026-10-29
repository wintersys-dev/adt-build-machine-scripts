#!/bin/sh
########################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will add a new DNS record to the DNS provider
#########################################################################
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
################################################################################
################################################################################
#set -x
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

sub_domain="`/bin/echo ${1} | /usr/bin/awk -F'.' '{print $1}'`"
domain_url="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"
ip="${2}"

#linode_config_file="/root/.config/dns-linode-cli"

#if ( [ -f /root/snap/linode-cli/current/.config/dns-linode-cli  ] )
#then
#        linode_config_file="/root/snap/linode-cli/current/.config/dns-linode-cli"
#fi

#Make damn sure that the DNS record gets added to the DNS system                        
#export LINODE_CLI_CONFIG="${linode_config_file}"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"
export LINODE_CLI_TOKEN="${TOKEN}"

domain_id="`/usr/local/bin/linode-cli domains list --no-defaults --json | /usr/bin/jq -r '.[] | select (.domain | contains("'${domain_url}'")).id'`"

if ( [ "$?" != "0" ] )
then
	unset LINODE_CLI_TOKEN
    exit 1
fi

/usr/local/bin/linode-cli domains records-create "${domain_id}" --type A --name "${sub_domain}" --target "${ip}" --ttl_sec 60 --no-defaults

if ( [ "$?" != "0" ] )
then
    status "Failed to add DNS record for domain ${domain_url}, sub domain ${sub_domain} and ip address ${ip}"
	unset LINODE_CLI_TOKEN
    exit 1
fi
	
unset LINODE_CLI_TOKEN


