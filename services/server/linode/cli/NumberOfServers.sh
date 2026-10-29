#!/bin/sh
############################################################################################
# Author : Peter Winter
# Date   : 13/07/2016
# Description : This scripts lists the number of servers of a particular type that are running
############################################################################################
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
##########################################################################################
##########################################################################################
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
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>" 
        exit 1
fi

server_type="${1}"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

linode_run linodes list | /usr/bin/jq -r '.[] | select (.label | contains("'${server_type}'")).id' | /usr/bin/wc -l

if ( [ "$?" != "0" ] )
then
        exit 1
fi
