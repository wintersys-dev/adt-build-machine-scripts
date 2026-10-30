#!/bin/sh
###################################################################################
# @file        PerformDatastoreMount.sh
# @brief       Automated S5cmd Datastore Bucket Verification and Creation Utility.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates the operational verification and creation of a 
#              target S3 datastore bucket using the ultra-fast s5cmd utility. It 
#              dynamically extracts the host base endpoint from an s5cmd credentials 
#              profile matching a numeric instance identifier. If the cloud storage 
#              bucket is found to be uninitialised or missing, the script executes a 
#              make-bucket (mb) transaction against the specified endpoint.
#
# @param       $1  [Required] The exact name of the S3 datastore bucket to verify or create.
# @param       $2  [Required] Integer ID used to select the indexed s5cmd configuration profile.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /root/.s5cfg-${count} workspace credentials file for endpoint and credential routing.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - /usr/bin/s5cmd parallel S3 command-line execution tool binary.
#
# @security    
#              - Requires root-level access privileges to inspect and evaluate specific credential files.
#              - Routes structural setup diagnostic outputs securely to absolute null space (2>&1 >/dev/null).
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

host_base="`/bin/grep ^host_base /root/.s5cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 

if ( [ "`/usr/bin/s5cmd --credentials-file /root/.s5cfg-${count} --endpoint-url https://${host_base} ls s3://${datastore_to_mount}  2>/dev/null`" = "" ] )
then
  /usr/bin/s5cmd --credentials-file /root/.s5cfg-${count} --endpoint-url https://${host_base} mb s3://${datastore_to_mount}  2>&1 >/dev/null
  if ( [ "$?" != "0" ] )
  then
    status "Failed to mount bucket s3://${datastore_to_mount}"
    exit 1
  fi
fi



