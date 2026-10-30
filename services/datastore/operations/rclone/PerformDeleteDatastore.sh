#!/bin/sh 
###################################################################################
# @file        PerformDeleteDatastore.sh
# @brief       Automated S3 Datastore Bucket Purging and Removal Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates the destruction and purging of an entire target 
#              S3 cloud datastore bucket. It dynamically extracts the host base endpoint
#              from a specific, micro-targeted rclone configuration profile instance.
#              The script completely removes the storage structures and forcefully purges 
#              all internal directory tracks using raw backend orchestration tool mappings.
#
# @param       $1  [Required] The exact name of the S3 datastore bucket to purge and delete.
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
#              - Requires root-level evaluation access to process system rclone configuration tokens.
#              - Routes diagnostic payloads securely to the absolute null space (2>&1 >/dev/null).
#              - Forces tool maps to run exclusively from static, validated platform partitions (/bin, /usr/bin).
#
# @exit        0  Success: Target cloud datastore and its directory configurations were dropped.
# @exit        1  Failure: Missing parameters or an error returned during bucket destruction loops.
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
        status "Usage: $0 <datastore_to_delete> <count>"
        exit 1
fi

datastore_to_delete="${1}"
count="${2}"

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} | /bin/grep "^endpoint" | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} purge s3:${datastore_to_delete}  2>&1 >/dev/null
if ( [ "$?" != "0" ] )
then
        status "Failed to delete datastore"
        exit 1
fi
