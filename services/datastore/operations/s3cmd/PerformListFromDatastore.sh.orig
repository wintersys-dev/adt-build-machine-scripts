#!/bin/sh 
###################################################################################
# @file        PerformListFromDatastore.sh
# @brief       Automated S3 Datastore Object Content Listing and Parsing Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level item inspection within targeted cloud
#              datastores using s3cmd. It extracts the storage endpoint configuration 
#              from the primary s3cmd configuration profile, queries the target S3 path 
#              recursively, and processes the raw metadata through filtering text parsing 
#              streams to isolate and print individual target file basenames cleanly.
#
# @param       $1  [Required] Target S3 bucket pathway or file pattern to inspect.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /usr/bin/s3cmd storage integration command-line software utility.
#              - /root/.s3cfg-1 base primary cluster registration configuration file.
#
# @security    
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#              - Limits terminal output purely to parsed un-hashed structural path basenames.
#
# @exit        0  Success: Target path successfully interrogated and structural objects listed.
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

cfg_file="/root/.s3cfg-1"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
/usr/bin/s3cmd --recursive --config="$cfg_file" --host="https://${host_base}" ls "s3://${file_to_list}" 2>/dev/null | /usr/bin/awk '{print $NF}' | /usr/bin/sed 's|s3://||' | /usr/bin/awk -F'/' '{print $NF}'
s3cmd_status=$?
set -e

if [ $s3cmd_status -ne 0 ]
then
    /bin/echo "Failed to list file ${file_to_list} from datastore"
    status "s3cmd failed to list objects recursively at s3://${file_to_list} (Exit code: $s3cmd_status)"
    exit 1
fi

exit 0
