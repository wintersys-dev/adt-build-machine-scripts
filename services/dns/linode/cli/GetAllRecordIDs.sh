#!/bin/sh
#################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will retrieve all the record id's for the selected
# domain name (website url)
#################################################################################
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
set -e

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

domain_url="`/bin/echo ${1} | /usr/bin/cut -d'.' -f2-`"
sub_domain="`/bin/echo ${1} | /usr/bin/awk -F'.' '{print $1}'`"

linode_config_file="/root/.config/dns-linode-cli"

if ( [ -f /root/snap/linode-cli/current/.config/linode-cli ] )
then
        linode_config_file="/root/snap/linode-cli/current/.config/linode-cli"
fi

export LINODE_CLI_CONFIG=${linode_config_file}

domain_id="`/usr/local/bin/linode-cli domains list --no-defaults --json | /usr/bin/jq -r '.[] | select (.domain | contains("'${domain_url}'")).id'`"
/usr/local/bin/linode-cli domains records-list ${domain_id}  --name "${sub_domain}" --no-defaults --json | /usr/bin/jq -r '.[].id'

if ( [ $? != "0" ] )
then
        status "Failed to get all record IDs for domain ${domain_id} and subdomain ${sub_domain}"
        unset LINODE_CLI_CONFIG
        exit  1
fi
unset LINODE_CLI_CONFIG
