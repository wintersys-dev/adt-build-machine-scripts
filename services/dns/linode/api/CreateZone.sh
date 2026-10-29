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
#set -x
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

domain_url="$(/bin/echo ${1} | /usr/bin/cut -d'.' -f2-)"

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
DNS_USERNAME="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_USERNAME)"

domain_id="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s "https://api.linode.com/v4/domains" | jq --arg dom "${domain_url}" '.data[] | select(.domain == $dom) | .id')"

if [ "${domain_id}" = "" ]
then
        /bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST "https://api.linode.com/v4/domains" -H "Content-Type: application/json" -d '{ "type": "master", "domain": "'"${domain_url}"'", "soa_email": "'"${DNS_USERNAME}"'" }'
fi

if [ $? != "0" ]
then
        status "Fauled to create zone in the DNS system"
        exit  1
fi
