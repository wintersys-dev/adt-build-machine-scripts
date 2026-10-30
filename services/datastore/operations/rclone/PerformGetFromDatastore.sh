#!/bin/sh 
###################################################################################
# @file        PerformGetFromDatastore.sh
# @brief       Automated S3 Datastore Object Retrieval and Copying Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates fetching or copying a specific object target from 
#              a managed S3 cloud datastore into a local path workspace. It queries the 
#              first-order rclone configuration profile directly to extract the correct 
#              cloud backend host base endpoint, skipping downstream distributed cluster loops 
#              to pull the object source immediately from the master repo.
#
# @param       $1  [Required] Relative cloud object pathway or file target to be fetched.
# @param       $2  [Required] Local directory target workspace path to deposit the retrieved file.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /root/.config/rclone/rclone.conf-1 base master workspace profile for endpoint routing.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - /usr/bin/rclone cloud storage sync and manipulation tool binary.
#
# @security    
#              - Anchors operations to the root profile context (`rclone.conf-1`) to verify source integrity.
#              - Shunts system diagnostic channels silently into internal null streams (2>/dev/null).
#              - Forces script automation tools to map to unalterable system bin environments (/bin, /usr/bin).
#
# @exit        0  Success: Target object configuration was successfully retrieved and staged locally.
# @exit        1  Failure: Missing parameters or an error code returned by the rclone copy driver.
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

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-1 | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-1 --s3-endpoint ${host_base}  copy s3:${file_to_get} ${destination}  2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to get file ${file_to_get} from datastore"
        exit 1
fi
