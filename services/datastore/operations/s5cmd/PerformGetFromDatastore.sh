#!/bin/sh 
###################################################################################
# @file        PerformGetFromDatastore.sh
# @brief       Automated S3 Datastore Object Retrieval and Local Ingestion Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level file download and transfer tasks from
#              managed cloud datastores to local file system targets using s5cmd.
#              It extracts target cloud endpoint parameters from the primary s5cmd
#              credentials profile, configures single-node high-performance data pipes, 
#              and copies the requested remote object cleanly into the destination path.
#
# @param       $1  [Required] S3 bucket target pathway and the specific object key to pull.
# @param       $2  [Required] Local directory path or target file name destination for the download.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /usr/bin/s5cmd high-performance storage integration software utility.
#              - /root/.s5cfg-1 base primary cluster registration credentials file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Cloud object securely retrieved and copied to local workspace destinations.
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
    /bin/echo "Usage: $0 <file_to_get> <destination>"
    status "Script invoked with missing arguments."
    exit 1
fi

file_to_get="$1"
destination="$2"

cfg_file="/root/.s5cfg-1"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" cp "s3://${file_to_get}" "${destination}" 2>/dev/null
s5cmd_status=$?
set -e

if [ $s5cmd_status -ne 0 ]
then
    /bin/echo "Failed to get file ${file_to_get} from datastore"
    status "s5cmd failed to download s3://${file_to_get} to ${destination} (Exit code: $s5cmd_status)"
    exit 1
fi

exit 0
