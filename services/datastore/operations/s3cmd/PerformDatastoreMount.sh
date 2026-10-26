#!/bin/sh
#########################################################################################
# Author: Peter Winter
# Date :  9/4/2021
# Tool/Script: Automated S3 Datastore Mounting/Creation utility
# Author:      Peter Winter
# Date:        9/4/2021
# Suite:       The Agile Deployment Toolkit
# 
# Description: This script automates the mounting of an S3 datastore
#
# Arguments:
#              $1 - <datastore_to_mount> : Datastore to be mounted
#              $2 - <count>              : Integer ID used to select the rclone config profile.
#
# Requirements:
#              - /usr/bin/s3cmd installed and accessible.
#              - A valid profile located at /root/.config/rclone/rclone.conf-${count}
#              - Standard output/logging routes configured on File Descriptors 3 and 4.
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
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
#########################################################################################
#########################################################################################
#set -x

set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"


if ( [ "${1}" = "" ] || [ "${2}" = "" ] )
then
        status "Error: 2 arguments are required."
        status "Usage: $0 <datastore_to_mount> <count>"
        exit 1
fi

datastore_to_mount="$1"
count="${2}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

host_base="`/bin/grep ^host_base /root/.s3cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 

if ( [ "`/usr/bin/s3cmd --config=/root/.s3cfg-${count} --host=https://${host_base} ls s3://${datastore_to_mount} 2>/dev/null`" = "" ] )
then
  /usr/bin/s3cmd --config=/root/.s3cfg-${count} --host=https://${host_base} mb s3://${datastore_to_mount}  2>&1 >/dev/null
  if ( [ "$?" != "0" ] )
  then
    status "Failed to mount bucket s3://${datastore_to_mount}"
    exit 1
  fi
fi
