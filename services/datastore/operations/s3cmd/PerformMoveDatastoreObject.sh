#!/bin/sh
######################################################################################
# Tool/Script: Automated S3 Object Relocation and Renaming Utility
# Author:      Peter Winter
# Date:        9/4/2021
# Suite:       The Agile Deployment Toolkit
# 
# Description: This script automates moving or renaming objects within an S3 cloud 
#              datastore using the rclone CLI tool. By resolving storage endpoints 
#              dynamically from numbered profile configurations, it handles file 
#              relocation natively on the remote storage layer without downloading 
#              files locally.
#
# Arguments:
#              $1 - <original_object> : Source object path within the S3 bucket.
#              $2 - <new_object>      : Target destination object path or new filename.
#              $3 - <count>           : Integer ID used to select the rclone config profile.
#
# Requirements:
#              - /usr/bin/s3cmd installed and accessible.
#              - A valid profile located at /root/.config/rclone/rclone.conf-\${count}
#              - Standard output/logging routes configured on File Descriptors 3 and 4.
######################################################################################
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
#######################################################################################
#######################################################################################
#set -x

set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] )
then
        status "Error: 3 arguments are required."
        status "Usage: $0 <original_object> <new_object> <count>"
        exit 1
fi

original_object="$1"
new_object="$2"
count="$3"

host_base="`/bin/grep ^host_base /root/.s3cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/s3cmd --config=/root/.s3cfg-${count} --host=https://${host_base} mv s3://${original_object} s3://${new_object}  2>&1 >/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to move object ${original_object} to object ${new_object}"
        exit 1
fi
