#!/bin/sh
########################################################################################
# Author : Peter Winter
# Date:    13/07/2016
# Description : This script will determine if a machine with a given name is running or not
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

if [ "${1}" = "" ]
then
    status "Error: Server type argument is required."
    status "Usage: $0 <server_type>" 
    exit 1
fi

server_type="${1}"
REGION="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION)"
TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
export LINODE_CLI_TOKEN="${TOKEN}"

if [ "`/usr/local/bin/linode-cli --no-defaults --json linodes list --region ${REGION} | /usr/bin/jq -r '.[] | select (.label | contains("'${server_type}'")).status' 2>/dev/null`" = "running" ]
then
	/bin/echo "running"
else
	/bin/echo "not running"
fi
unset LINODE_CLI_TOKEN

