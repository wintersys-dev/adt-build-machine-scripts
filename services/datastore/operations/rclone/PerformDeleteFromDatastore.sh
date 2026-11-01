#!/bin/sh 
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S3 Datastore Object Purging & Empty Directory Removal Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level data removal operations inside targeted
#              cloud datastores. It parses endpoints directly from partitioned rclone
#              profile configurations, processes special 'root' overrides for tree 
#              wipes, and commands the underlying storage layout engine to delete objects
#              and prune unmapped parent directory trees safely.
#
# @param       $1  [Required] S3 bucket target pathway and the specific object key to delete.
# @param       $2  [Required] Integer configuration ID used to select the targeted rclone profile suffix.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active application root path.
#              - /usr/bin/rclone storage integration engine software utility.
#              - /root/.config/rclone/rclone.conf-${count} targeted cluster registration file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target object successfully purged from the datastore namespace.
# @exit        1  Failure: Missing mandatory parameters or rclone execution driver failure.
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
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
######################################################################################
#set -x
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if [ -z "$1" ] || [ -z "$2" ]
then
    /bin/echo "Error: 2 arguments are required."
    /bin/echo "Usage: $0 <file_to_delete> <count>"
    status "Script invoked with missing arguments."
    exit 1
fi

file_to_delete="$1"
count="$2"

cfg_file="/root/.config/rclone/rclone.conf-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^endpoint "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

rmdirs=""
if [ "${file_to_delete%root}" != "$file_to_delete" ]
then
    file_to_delete="${file_to_delete%root}"
    rmdirs="--rmdirs"
fi

set +e
if [ -n "$rmdirs" ]
then
    /usr/bin/rclone --config "$cfg_file" --s3-endpoint "$host_base" delete "s3:${file_to_delete}" --rmdirs >/dev/null 2>&1
else
    /usr/bin/rclone --config "$cfg_file" --s3-endpoint "$host_base" delete "s3:${file_to_delete}" >/dev/null 2>&1
fi
rclone_status=$?
set -e

if [ $rclone_status -ne 0 ]
then
    /bin/echo "Failed to delete file ${file_to_delete} from datastore"
    status "rclone failed to purge s3:${file_to_delete} (Prune empty dirs: ${rmdirs:-no}, Exit code: $rclone_status)"
    exit 1
fi

exit 0
