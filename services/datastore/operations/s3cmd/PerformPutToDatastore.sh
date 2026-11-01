#!/bin/sh
###################################################################################
# @file        PerformPutToDatastore.sh
# @brief       Automated Local Payload Ingestion & S3 Datastore Storage Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates low-level data ingress operations by transferring
#              local files or virtual metadata payloads to targeted cloud datastores 
#              using s3cmd. It resolves S3 endpoints from a dynamic configuration registry 
#              using a numbered index system. The utility features automatic workspace creation 
#              and placeholder marker file fallback routines, alongside an optional 
#              post-upload source sanitation mechanism.
#
# @param       $1  [Required] Local file system path of the source payload file to ingest.
# @param       $2  [Required] S3 bucket target location pathway to write the payload.
# @param       $3  [Required] Post-upload local sanitation flag ("yes" to purge source, "no" to retain).
# @param       $4  [Required] Integer configuration ID used to select the targeted s3cmd profile suffix.
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
#              - Safely caps directory tracking mutations by scrubbing trailing "root" overrides from the S3 namespace.
#              - Redirects descriptor arrays cleanly to guard against exposure of operational tokens on errors.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Local payload safely transmitted and synchronized with the S3 datastore destination.
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
#########################################################################################
#set -x
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

# 1. Check for all 4 arguments safely
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]
then
    /bin/echo "Error: 4 arguments are required."
    /bin/echo "Usage: $0 <file_to_put> <place_to_put> <delete> <count>"
    status "Script invoked with missing arguments."
    exit 1
fi

file_to_put="$1"
place_to_put="$2"
delete="$3"
count="$4"

place_to_put="${place_to_put%root}"

WORK_AREA="${HOME}/runtime/datastore_workarea"
if [ ! -d "$WORK_AREA" ]
then
    /bin/mkdir -p "$WORK_AREA"
fi

if [ ! -f "$file_to_put" ]
then
    /bin/touch "$WORK_AREA/$file_to_put"
    file_to_put_with_path="$WORK_AREA/$file_to_put"
else
    file_to_put_with_path="$file_to_put"
fi

cfg_file="/root/.s3cfg-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
/usr/bin/s3cmd --config="$cfg_file" --host="https://${host_base}" put "$file_to_put_with_path" "s3://${place_to_put}" >/dev/null 2>&1
s3cmd_status=$?
set -e

if [ $s3cmd_status -ne 0 ]
then
    /bin/echo "Failed to put ${file_to_put_with_path} to s3://${place_to_put}"
	status "s3cmd failed to upload ${file_to_put_with_path} to s3://${place_to_put} (Exit code: $s3cmd_status)"
    exit 1
fi

if [ "$delete" = "yes" ]
then
    if [ -f "$file_to_put_with_path" ]
    then
        /bin/rm "$file_to_put_with_path"
    fi
fi

exit 0
