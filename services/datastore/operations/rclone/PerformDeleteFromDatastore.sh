#!/bin/sh 
####################################################################################
# Author: Peter Winter
# Date :  9/4/2021
# Tool/Script: Automated S3 Datastore Mounting/Creation utility
# Author:      Peter Winter
# Date:        9/4/2021
# Suite:       The Agile Deployment Toolkit
# 
# Description: This script automates the deletion of a specific file from a datastore
#
# Arguments:
#              $1 - <file_to_delete>     : File held in the datastore to be deleted
#              $2 - <count>              : Integer ID used to select the rclone config profile.
#
# Requirements:
#              - /usr/bin/rclone installed and accessible.
#              - A valid profile located at /root/.config/rclone/rclone.conf-${count}
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


if ( [ "${1}" = "" ] || [ "${2}" = "" ] )
then
        status "Error: 2 arguments are required."
        status "Usage: $0 <file_to_delete> <count>"
        exit 1
fi


file_to_delete="${1}"
count="${2}"

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} | /bin/grep "^endpoint" | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
include=""
if ( [ "${file_to_delete}" != "" ] && [ "`/bin/echo ${file_to_delete} | /bin/grep '*'`" != "" ] )
then
  file_to_include="`/bin/echo ${file_to_delete} | /usr/bin/awk -F'/' '{print $NF}'`"
  include="--filter '+ "${file_to_include}"'"
  file_to_delete="`/bin/echo ${file_to_delete} | /usr/bin/cut -d'/' -f1`"
fi

/usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} ${include} delete s3:${file_to_delete}  2>&1 >/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to delete file ${file_to_delete} from datastore"
        exit 1
fi
