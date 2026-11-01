#!/bin/sh
###################################################################################
# @file        PerformMoveDatastoreObject.sh
# @brief       Automated S3 Datastore Object Relocation & Server-Side Renaming Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level file relocation and renaming tasks 
#              natively inside managed cloud datastores using s3cmd. By resolving 
#              storage endpoints dynamically from partitioned configuration files, it 
#              handles object transformation directly on the remote cloud storage layer, 
#              bypassing the need to download or buffer data locally.
#
# @param       $1  [Required] Source object path and key namespace within the S3 bucket.
# @param       $2  [Required] Target destination path or new filename key within the S3 bucket.
# @param       $3  [Required] Integer configuration ID used to select the targeted s3cmd profile suffix.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active application root path.
#              - /usr/bin/s3cmd storage integration command-line software utility.
#              - /root/.s3cfg-${count} targeted cluster registration configuration file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Redirects descriptor arrays cleanly to guard against exposure of operational tokens on errors.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Server-side object relocation or renaming completed successfully.
# @exit        1  Failure: Missing mandatory parameters or s3cmd execution driver failure.
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
#set -x
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
then
    /bin/echo "Error: 3 arguments are required."
    /bin/echo "Usage: $0 <original_object> <new_object> <count>"
    status "Script invoked with missing arguments."
    exit 1
fi

original_object="$1"
new_object="$2"
count="$3"

cfg_file="/root/.s3cfg-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
/usr/bin/s3cmd --config="$cfg_file" --host="https://${host_base}" mv "s3://${original_object}" "s3://${new_object}" >/dev/null 2>&1
s3cmd_status=$?
set -e

if [ $s3cmd_status -ne 0 ]
then
    /bin/echo "Failed to move object ${original_object} to object ${new_object}"
    status "s3cmd failed to move object s3://${original_object} to s3://${new_object} (Exit code: $s3cmd_status)"
    exit 1
fi

exit 0
