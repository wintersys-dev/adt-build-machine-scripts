#!/bin/sh
#########################################################################################
# Author: Peter Winter
# Date :  9/4/2016
# Description: Implement the putting of a file from the filesystem of the server to a
# datastore
##########################################################################################
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
#########################################################################################
#########################################################################################
#set -x

set -e

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ]  )
then
        status "Error: 4 arguments are required."
        status "Usage: $0 <file_to_put> <place_to_put> <delete> <count>"
        exit 1
fi

file_to_put="$1"
place_to_put="$2"
delete="$3"
count="$4"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"

if ( [ "${place_to_put}" = "root" ] )
then
        place_to_put=""
fi

if ( [ ! -d  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/datastore_workarea ] )
then
        /bin/mkdir -p  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/datastore_workarea
fi

if ( [ ! -f ${file_to_put} ] )
then
        #if there is no file on the file system we can assume that we are being used as a marker like an IP address, so create out own marker file
        /bin/touch  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/datastore_workarea/${file_to_put}
        file_to_put="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/datastore_workarea/${file_to_put}"
fi

place_to_put="`/bin/echo ${place_to_put} | /bin/sed 's;\/$;;g'`"
host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} copy ${file_to_put} s3:${place_to_put}

if ( [ "${delete}" = "yes" ] )
then
        if ( [ -f ${file_to_put} ] )
        then
                /bin/rm ${file_to_put}
        fi
fi
