#!/bin/sh
########################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will delete a record from the DNS provider given
# a record ID and a domain name
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
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

record_id="${1}"
domain_url="`/bin/echo ${2} | /usr/bin/cut -d'.' -f2-`"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

domain_id="`curl -H "Authorization: Bearer $TOKEN" https://api.linode.com/v4/domains | jq -r '.data[] | select(.domain | contains("'$domain_url'")).id'`"
curl -s -X DELETE -H "Authorization: Bearer $TOKEN"  "https://api.linode.com/v4/domains/${domain_id}/records/${record_id}"

if ( [ "$?" != "0" ] )
then
        status "Failed to delete record from DNS system"
        exit 1
fi
