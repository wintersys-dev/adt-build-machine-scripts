#!/bin/sh 
###################################################################################
# @file        PerformListFromDatastore.sh
# @brief       Automated S3 Datastore Object Content Listing and Parsing Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level item inspection within targeted cloud
#              datastores. It extracts the storage endpoint configuration from standard
#              rclone profile records, queries the target S3 path, and reads back object 
#              metadata. It passes the raw endpoint output through filtering text parsing 
#              streams to isolate and print individual target file basenames cleanly.
#
# @param       $1  [Required] Target S3 bucket pathway or file pattern to inspect.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/homedir.dat configuration file tracking the active application root path.
#              - /usr/bin/rclone storage integration engine software utility.
#              - /root/.config/rclone/rclone.conf-1 base primary cluster registration file.
#
# @security    
#              - Strips global wildcard assets (`*`) from target inputs to limit unexpected pattern extraction.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Target path successfully interrogated and structural objects listed.
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

# 1. Check for the 1 required argument safely
if [ -z "$1" ]
then
    /bin/echo "Error: 1 argument is required."
    /bin/echo "Usage: $0 <file_to_list>"
    status "Script invoked with missing arguments."
    exit 1
fi

file_to_list="$1"

# Strip wildcard markers defensively
file_to_list=$(/bin/echo "$file_to_list" | /usr/bin/tr -d '*')

cfg_file="/root/.config/rclone/rclone.conf-1"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^endpoint "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
/usr/bin/rclone --config "$cfg_file" --s3-endpoint "$host_base" ls "s3:${file_to_list}" 2>/dev/null | /usr/bin/awk '{print $NF}' | /bin/sed 's|s3://||' | /usr/bin/awk -F'/' '{print $NF}'
rclone_status=$?
set -e

if [ $rclone_status -ne 0 ]
then
    /bin/echo "Failed to list file ${file_to_list} from datastore"
    status "rclone failed to list objects at s3:${file_to_list} (Exit code: $rclone_status)"
    exit 1
fi

exit 0
