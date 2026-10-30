#!/bin/sh
###################################################################################
# @file        PerformMoveDatastoreObject.sh
# @brief       Automated S3 Datastore Object Relocation and Renaming Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates moving or renaming objects within an S3 cloud 
#              datastore using the rclone CLI tool. By resolving storage endpoints 
#              dynamically from numbered profile configurations, it handles file 
#              relocation natively on the remote storage layer without downloading 
#              files locally.
#
# @param       $1  [Required] Source object path or directory layer within the S3 bucket.
# @param       $2  [Required] Target destination object path or new filename inside the bucket.
# @param       $3  [Required] Integer ID used to select the indexed rclone configuration profile.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /root/.config/rclone/rclone.conf-${count} workspace configuration file for endpoint routing.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - /usr/bin/rclone cloud storage sync and manipulation tool binary.
#
# @security    
#              - Requires administrative privileges to read targeted configuration profile segments.
#              - Redirects unexpected platform communication errors safely away to standard null spaces (2>/dev/null).
#              - Keeps environment commands restricted to static system-level paths (/bin, /usr/bin).
#
# @exit        0  Success: Target object relocation and renaming transaction completed cleanly.
# @exit        1  Failure: Missing parameters or error status returned by the rclone moveto command.
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

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} moveto s3:${original_object} s3:${new_object}  2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to move object ${original_object} to object ${new_object}"
        exit 1
fi
