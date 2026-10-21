#!/bin/sh 
####################################################################################
# Author: Peter Winter
# Date :  9/4/2021
# Description: Automated S3 Object Content Listing and Parsing Utility.
#              This utility extracts the storage endpoint configuration from rclone,
#              queries the target S3 path, and reads back object metadata. It passes
#              the raw endpoint output through text parsing streams to isolate and 
#              print individual target file basenames cleanly to the environment.
# Parameters:
#              - <file_to_list>: Target S3 bucket path or file pattern to inspect.
# Requirements:
#              - Active rclone configuration asset located at /root/.config/rclone/rclone.conf-1
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
        status "Usage: $0 <file_to_list>"
        exit 1
fi

file_to_list="${1}"

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-1 --s3-endpoint ${host_base} ls s3:${file_to_list} | awk '{print $NF}'| sed 's|s3://||' | awk -F'/' '{print $NF}' 2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to list file ${file_to_list} from datastore"
        exit 1
fi
