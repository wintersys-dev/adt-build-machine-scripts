#!/bin/sh
###################################################################################
# @file        PerformListFromDatastore.sh
# @brief       Automated S3 Datastore Object Content Listing and Parsing Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.1
#
# @details     This script automates low-level item inspection within targeted cloud
#              datastores using s5cmd. It extracts the storage endpoint configuration 
#              from the primary s5cmd credential file, queries the target S3 path, 
#              and reads back object metadata. It passes the raw endpoint output 
#              through text parsing streams to isolate and print individual target 
#              file basenames cleanly to file descriptors.
#
# @param       $1  [Required] Target S3 bucket pathway or file pattern to inspect.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /usr/bin/s5cmd high-performance storage integration software utility.
#              - /root/.s5cfg-1 base primary cluster registration credentials file.
#              - Standard output/logging routes configured on File Descriptors 3 and 4.
#
# @security    
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#              - Filters pipeline output to restrict terminal visibility to targeted metadata records.
#
# @exit        0  Success: Target path successfully interrogated and structural objects listed.
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
    "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

# Verify required parameters
if [ -z "$1" ]
then
    status "Error: 1 argument is required."
    status "Usage: $0 <file_to_list>"
    status "Script invoked with missing arguments."
    exit 1
fi

file_to_list="$1"

cfg_file="/root/.s5cfg-1"
if [ ! -f "$cfg_file" ]
then
    status "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

# Temporary cache file used to secure exit code telemetry tracking data structures
s5_out="$(/bin/mktemp)"

set +e
# Run s5cmd query directly to an atomic target to isolate and evaluate the command process exit code
/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" ls "s3://${file_to_list}" > "$s5_out" 2>/dev/null
s5cmd_status=$?
set -e

if [ $s5cmd_status -eq 0 ]
then
    # Extract structural basename string blocks cleanly via awk once exit checks clear
    /usr/bin/awk '{print $NF}' "$s5_out"
    /bin/rm -f "$s5_out"
else
    /bin/rm -f "$s5_out"
    status "Failed to list file ${file_to_list} from datastore"
    status "s5cmd failed to list objects at s3://${file_to_list} (Exit code: $s5cmd_status)"
    exit 1
fi

exit 0


