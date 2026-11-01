#!/bin/sh 
###################################################################################
# @file        PerformDatastoreMount.sh
# @brief       Automated S3 Datastore Creation and Workspace Initialisation Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates backend volume initialisation for target cloud
#              datastores using s5cmd. It resolves endpoint layout settings from dynamic
#              s5cmd credential files, executes availability checks, and provisions 
#              the required bucket structure inside target S3 object storage targets
#              if it is not already present.
#
# @param       $1  [Required] Target datastore directory or S3 bucket name namespace.
# @param       $2  [Required] Integer configuration ID used to select the targeted s5cmd profile suffix.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active application root path.
#              - /usr/bin/s5cmd high-performance storage integration software utility.
#              - /root/.s5cfg-${count} targeted credentials and cluster configuration file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target bucket exists or was successfully created in the S3 backend.
# @exit        1  Failure: Missing mandatory parameters or s5cmd was unable to provision the datastore.
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
#set -x
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if [ -z "$1" ] || [ -z "$2" ]
then
    /bin/echo "Error: 2 arguments are required."
    /bin/echo "Usage: $0 <datastore_to_mount> <count>"
    status "Script invoked with missing arguments."
    exit 1
fi

datastore_to_mount="$1"
count="$2"

cfg_file="/root/.s5cfg-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
check_output=$(/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" ls "s3://${datastore_to_mount}" 2>/dev/null)
check_status=$?

if [ $check_status -ne 0 ] || [ -z "$check_output" ]
then
    /usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" mb "s3://${datastore_to_mount}" >/dev/null 2>&1
    mb_status=$?
    
    if [ $mb_status -ne 0 ]
    then
        /bin/echo "Failed to mount bucket s3://${datastore_to_mount}"
        status "s5cmd failed to create bucket s3://${datastore_to_mount} (Exit code: $mb_status)"
        exit 1
    fi
fi
set -e

exit 0



