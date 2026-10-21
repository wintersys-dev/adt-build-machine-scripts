#!/bin/sh 
####################################################################################
# Author:      Peter Winter
# Date:        9/4/2021
# Suite:       The Agile Deployment Toolkit
# 
# Description: This script will discover if a datastore already exists
#
# Arguments:
#              $1 - <datastore_to_list>     : Name of the datastore to check
#
# Requirements:
#              - /usr/bin/rclone installed and accessible.
#              - A valid profile located at /root/.config/rclone/rclone.conf-1
#              - Standard output/logging routes configured on File Descriptors 3 and 4.
#######################################################################################
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
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
######################################################################################
######################################################################################
#set -x
set -e

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

if ( [ "${1}" = "" ] )
then
        status "Error: 1 argument is required."
        status "Usage: $0 <datastore_to_list>"
        exit 1
fi

datastore_to_list="${1}"

flag="-x"

if ( [ "${datastore_to_list}" = "all" ] )
then
        datastore_to_list=""
        flag=""
fi

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-1 --s3-endpoint ${host_base} lsd s3:  | awk '{print $NF}'| sed 's|/.*||' | /bin/grep ${flag} "${datastore_to_list}" 2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to list datastore ${datastore_to_list}"
        exit 1
fi
