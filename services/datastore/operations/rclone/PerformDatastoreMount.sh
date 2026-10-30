#!/bin/sh
###################################################################################
# @file        PerformDatastoreMount.sh
# @brief       Automated S3 Datastore Bucket Verification and Creation Utility.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates the operational verification and creation of a 
#              target S3 datastore bucket. It dynamically extracts the host base endpoint
#              from a designated rclone configuration profile matching a numeric instance identifier.
#              If the cloud storage endpoint is found to be uninitialised or empty, the script
#              subsequently creates the requested bucket path on the storage provider.
#
# @param       $1  [Required] The exact name of the S3 datastore bucket to verify or create.
# @param       $2  [Required] Integer ID used to select the indexed rclone configuration profile.
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
#              - Requires root-level access privileges to inspect and evaluate specific rclone profiles.
#              - Implements quiet diagnostic evaluation (2>/dev/null) to safely hide raw platform responses.
#              - Binds operational tools explicitly to full filesystem binary paths (/bin, /usr/bin).
#
# @exit        0  Success: Target cloud datastore was validated or instantiated successfully.
# @exit        1  Failure: Missing parameters or an error returned during bucket path creation.
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

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 

if ( [ "`/usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} ls s3: 2>/dev/null`" = "" ] )
then
        /usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} mkdir s3:${datastore_to_mount} 
        if ( [ "$?" != "0" ] )
        then
                status "Failed to mount bucket s3://${datastore_to_mount}"
                exit 1
        fi
fi

