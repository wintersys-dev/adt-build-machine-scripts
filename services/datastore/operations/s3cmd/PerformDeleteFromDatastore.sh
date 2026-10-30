#!/bin/sh 
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S3cmd Datastore Object and Target File Deletion Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates the deletion of a specific file or target path from
#              a managed S3 cloud datastore using the s3cmd utility. It dynamically extracts
#              the required cloud host base endpoint from a numbered s3cmd configuration profile.
#              If the target path contains a trailing 'root' specifier, the driver applies
#              a recursive deletion flag, strip tokens, and sanitizes wildcard markers to target
#              the storage layer natively.
#
# @param       $1  [Required] File path or relative cloud object target directory to delete.
# @param       $2  [Required] Integer ID used to select the indexed s3cmd configuration profile.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /root/.s3cfg-${count} workspace configuration file for endpoint and credential routing.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - /usr/bin/s3cmd command-line tool for managing Amazon S3 and compatible storage providers.
#
# @security    
#              - Demands root execution authorization levels to read restricted profile targets.
#              - Redirects unexpected platform communication errors safely away to standard null spaces (2>/dev/null).
#              - Keeps environment commands restricted to static system-level paths (/bin, /usr/bin).
#
# @exit        0  Success: Target file or structural object directory was discarded cleanly.
# @exit        1  Failure: Missing parameters or error status returned by the s3cmd deletion task.
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
        status "Usage: $0 <file_to_delete> <count>"
        exit 1
fi

file_to_delete="${1}"
count="${2}"

recursive=""
if ( [ "`/bin/echo ${file_to_delete} | /bin/grep 'root$'`" != "" ] )
then
  file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed "s/root$//g"`"
  recursive="--recursive"
fi

file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed 's/\*$//g'`"
host_base="`/bin/grep ^host_base /root/.s3cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`" 
/usr/bin/s3cmd ${recursive} --force  --config=/root/.s3cfg-${count} --host=https://${host_base} del s3://${file_to_delete} 2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to delete file ${file_to_delete} from datastore"
        exit 1
fi
