#!/bin/sh 
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S3 Datastore Object Purging & Wildcard Tree Deletion Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level data removal operations inside targeted
#              cloud datastores using the high-performance s5cmd tool. It extracts 
#              endpoint parameters from dynamic s5cmd credential registries, evaluates 
#              special 'root' designators to append wildcards for multi-object tree purges, 
#              and commands the storage engine to discard the matching remote namespaces.
#
# @param       $1  [Required] S3 bucket target pathway and the specific object key to remove.
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
#              - Safely handles broad namespace deletes by evaluating string variables before wildcard appending.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target object or directory tree successfully purged from the datastore.
# @exit        1  Failure: Missing mandatory parameters or s5cmd execution driver failure.
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

cfg_file="/root/.s5cfg-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

wildcard=""
if [ "${file_to_delete%root}" != "$file_to_delete" ]
then
    file_to_delete="${file_to_delete%root}"
    wildcard="*"
fi

set +e
/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" rm "s3://${file_to_delete}${wildcard}" 2>/dev/null
s5cmd_status=$?
set -e

if [ $s5cmd_status -ne 0 ]
then
    /bin/echo "Failed to delete file ${file_to_delete} from datastore"
    status "s5cmd failed to remove s3://${file_to_delete}${wildcard} (Exit code: $s5cmd_status)"
    exit 1
fi

exit 0

