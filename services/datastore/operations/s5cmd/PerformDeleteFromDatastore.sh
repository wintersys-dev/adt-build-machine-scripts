#!/bin/sh 
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S5cmd Datastore Object and Target File Deletion Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates the deletion of a specific file or target path from
#              a managed S3 cloud datastore using the high-performance s5cmd utility. It 
#              dynamically extracts the required cloud host base endpoint from a numbered 
#              s5cmd configuration profile. If the target path contains a trailing 'root' 
#              specifier, the driver automatically strips the token and appends a wildcard 
#              marker (*) to execute recursive object tree removal natively on the endpoint.
#
# @param       $1  [Required] File path or relative cloud object target directory to delete.
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
#              - Demands root execution authorization levels to read restricted profile targets.
#              - Redirects unexpected platform communication errors safely away to standard null spaces (2>/dev/null).
#              - Keeps environment commands restricted to static system-level paths (/bin, /usr/bin).
#
# @exit        0  Success: Target file or structural object directory was discarded cleanly.
# @exit        1  Failure: Missing parameters or error status returned by the s5cmd deletion task.
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

host_base="`/bin/grep ^host_base /root/.s5cfg-${count} | /usr/bin/awk -F'=' '{print  $NF}' | /bin/sed 's/ //g'`"
wildcard=""
if ( [ "`/bin/echo ${file_to_delete} | /bin/grep 'root$'`" != "" ] )
then
  file_to_delete="`/bin/echo ${file_to_delete} | /bin/sed "s/root$//g"`"
  wildcard="*"
fi
/usr/bin/s5cmd --credentials-file /root/.s5cfg-${count} --endpoint-url https://${host_base} rm s3://${file_to_delete}${wildcard}  2>/dev/null

if ( [ "$?" != "0" ] )
then
        status "Failed to delete file ${file_to_delete} from datastore"
        exit 1
fi
