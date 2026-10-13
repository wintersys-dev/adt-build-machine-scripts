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

email="${1}"
domain_url="`/bin/echo ${3} | /usr/bin/cut -d'.' -f2-`"

linode_config_file="/root/.config/dns-linode-cli"
        
if ( [ -f /root/snap/linode-cli/current/.config/linode-cli ] )
then
        linode_config_file="/root/snap/linode-cli/current/.config/linode-cli"
fi
                        
export LINODE_CLI_CONFIG=${linode_config_file}      

                
if ( [ "`/usr/local/bin/linode-cli domains list --domain ${domain_url} --json | jq '.[].id'`" = "" ] )
then
        /usr/local/bin/linode-cli domains create --type master --domain ${domain_url} --soa_email ${email} --no-defaults
fi

if ( [ $? != "0" ] )
then
        unset LINODE_CLI_CONFIG
        exit  1
fi
unset LINODE_CLI_CONFIG
