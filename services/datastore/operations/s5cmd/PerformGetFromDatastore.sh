#!/bin/sh 
####################################################################################
# Author: Peter Winter
# Date :  9/4/2021
# Tool/Script: Automated S3 Datastore utility to obtain a file from the datastore
# Author:      Peter Winter
# Date:        9/4/2021
# Suite:       The Agile Deployment Toolkit
# 
# Description: This script automates the deletion of a specific file from the datastore
#
# Arguments:
#              $1 - <file_to_get>     : File in a datastore to get
#              $2 - <destination>     : The local directory to place the file
#
# Requirements:
#              - /usr/bin/s5cmd installed and accessible.
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
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] )
then
        status "Error: 2 arguments are required."
        status "Usage: $0 <file_to_get> <destination>"
        exit 1
fi

file_to_get="${1}"
destination="${2}"

host_base="`/bin/grep ^host_base /root/.s5cfg-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
/usr/bin/s5cmd --credentials-file /root/.s5cfg-1 --endpoint-url https://${host_base} cp s3://${file_to_get} ${destination}  2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to get file ${file_to_get} from datastore"
        exit 1
fi
