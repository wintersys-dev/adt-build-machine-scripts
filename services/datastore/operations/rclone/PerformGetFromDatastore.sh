#!/bin/sh 
###################################################################################
# @file        PerformGetFromDatastore.sh
# @brief       Automated S3 Datastore Object Retrieval and Local Ingestion Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates down-level file transfer tasks from managed cloud
#              datastores to local file system targets. It extracts target cloud
#              endpoint parameters from static primary rclone profile structures,
#              configures single-node data pipes, and maps object assets down into
#              the requested endpoint destination folder.
#
# @param       $1  [Required] S3 bucket target pathway and the specific object key to copy.
# @param       $2  [Required] Local directory path or target file name destination for the download.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /usr/bin/rclone storage integration engine software utility.
#              - /root/.config/rclone/rclone.conf-1 base primary cluster registration file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Cloud object securely retrieved and copied to local workspace destinations.
# @exit        1  Failure: Missing mandatory parameters or rclone execution driver failure.
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

# 1. Check for all 2 arguments safely
if [ -z "$1" ] || [ -z "$2" ]
then
    /bin/echo "Error: 2 arguments are required."
    /bin/echo "Usage: $0 <file_to_get> <destination>"
    log_error "Script invoked with missing arguments."
    exit 1
fi

file_to_get="$1"
destination="$2"

cfg_file="/root/.config/rclone/rclone.conf-1"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^endpoint "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
/usr/bin/rclone --config "$cfg_file" --s3-endpoint "$host_base" copy "s3:${file_to_get}" "${destination}" 2>/dev/null
rclone_status=$?
set -e

if [ $rclone_status -ne 0 ]
then
    /bin/echo "Failed to get file ${file_to_get} from datastore"
    status "rclone failed to download s3:${file_to_get} to ${destination} (Exit code: $rclone_status)"
    exit 1
fi

exit 0
