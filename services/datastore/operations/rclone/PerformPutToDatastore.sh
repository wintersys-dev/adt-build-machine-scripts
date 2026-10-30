#!/bin/sh
###################################################################################
# @file        PerformPutToDatastore.sh
# @brief       Automated S3 Datastore Object Staging and File Upload Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script handles uploading individual local files or dynamically 
#              generated environment markers into a targeted S3 cloud datastore bucket. 
#              It reads server endpoint targets from a specified rclone configuration profile, 
#              allocates dedicated workspace areas under its active runtime environment, 
#              and carries out data transmissions natively. An optional post-upload parameter 
#              enables localized file storage purging to guarantee a minimal footprint.
#
# @param       $1  [Required] Absolute or relative local pathway of the file/marker to upload.
# @param       $2  [Required] Location path inside the S3 bucket ("root" maps to base destination).
# @param       $3  [Required] Cleanup instruction flag ("yes" triggers post-upload source deletion).
# @param       $4  [Required] Integer ID used to select the indexed rclone configuration profile.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
# @env         CLOUDHOST               System variable defining the underlying cloud provider.
# @env         BUILD_IDENTIFIER        System tracking variable isolating distinct platform deployments.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /root/.config/rclone/rclone.conf-${count} workspace configuration file for endpoint routing.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - GetVariableValue.sh system service wrapper infrastructure for lookup evaluations.
#              - /usr/bin/rclone cloud storage sync and manipulation tool binary.
#
# @security    
#              - Demands root execution authorization levels to read restricted profile targets.
#              - Shunts unexpected connection diagnostic information into quiet null targets (2>/dev/null).
#              - Mitigates system data footprints by isolating deletion evaluations strictly to validated targets.
#
# @exit        0  Success: Target data blocks or tracking flags were successfully uploaded.
# @exit        1  Failure: Missing parameters or an error returned during the upload routine.
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
#########################################################################################
#########################################################################################
#set -x

set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] || [ "${4}" = "" ]  )
then
        status "Error: 4 arguments are required."
        status "Usage: $0 <file_to_put> <place_to_put> <delete> <count>"
        exit 1
fi

file_to_put="$1"
place_to_put="$2"
delete="$3"
count="$4"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"

if ( [ "${place_to_put}" = "root" ] )
then
        place_to_put=""
fi

if ( [ ! -d  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/datastore_workarea ] )
then
        /bin/mkdir -p  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/datastore_workarea
fi

if ( [ ! -f ${file_to_put} ] )
then
        #if there is no file on the file system we can assume that we are being used as a marker like an IP address, so create out own marker file
        /bin/touch  ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/datastore_workarea/${file_to_put}
        file_to_put="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/datastore_workarea/${file_to_put}"
fi

host_base="`/bin/grep ^endpoint /root/.config/rclone/rclone.conf-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/rclone --config /root/.config/rclone/rclone.conf-${count} --s3-endpoint ${host_base} copy ${file_to_put} s3:${place_to_put}  2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to put ${file_to_put} to s3://${place_to_put}"
        exit 1
fi

if ( [ "${delete}" = "yes" ] )
then
        if ( [ -f ${file_to_put} ] )
        then
                /bin/rm ${file_to_put}
        fi
fi
