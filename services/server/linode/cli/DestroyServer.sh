#!/bin/sh
###################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This script will destroy the specified server by ip address
###################################################################################
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
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

linode_run() {
        (
                old_umask=$(umask)
                umask 077
                tmp_conf="${BUILD_HOME}/.linode-cfg.$$"
                trap 'rm -f "${tmp_conf}"' EXIT INT TERM
                export TOKEN="$TOKEN"
                envsubst < "${BUILD_HOME}/.linode-cli" > "${tmp_conf}"
                umask "$old_umask"
                export LINODE_CONFIG_PATH="${tmp_conf}"
                linode-cli --no-defaults --json "$@"
                unset TOKEN
                unset LINODE_CONFIG_PATH
        )
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] )
then
        status "Error: Server ip argument is required."
        status "Usage: $0 <server_ip>" 
        exit 1
fi

server_ip="${1}"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if ( [ "${server_ip}" != "" ] )
then
        server_id="`linode_run linodes list | /usr/bin/jq -r '.[] | select (.ipv4[] == "'${server_ip}'").id'`"

        if ( [ "$?" != "0" ] )
        then
                exit 1
        fi

        if ( [ "${server_id}" = "" ] )
        then
                server_ip="`${BUILD_HOME}/services/server/GetServerPublicIPAddressByIP.sh ${server_ip}`"
                server_id="`linode_run linodes list | /usr/bin/jq -r '.[] | select (.ipv4[] == "'${server_ip}'").id'`"

                if ( [ "$?" != "0" ] )
                then
                        exit 1
                fi
        fi

        /usr/local/bin/linode-cli linodes shutdown ${server_id}
        if ( [ "$?" != "0" ] )
        then
                exit 1
        fi

        count="0"
        while ( [ "`linode_run linodes view ${server_id} --format status --no-headers | jq -r '.[].status'`" != "offline" ] && [ "${count}" -lt "20" ] )
        do
                status "Waiting for machine with id: ${server_id} and ip address ${server_ip} to be offline following a shutdown request"
                /bin/sleep 10
                count="`/usr/bin/expr ${count} + 1`"
        done

        linode_run linodes delete ${server_id}

        if ( [ "$?" != "0" ] )
        then
                exit 1
        else
                status "Waiting for machine with id: ${server_id} and ip address ${server_ip} has been deleted"
        fi
fi
