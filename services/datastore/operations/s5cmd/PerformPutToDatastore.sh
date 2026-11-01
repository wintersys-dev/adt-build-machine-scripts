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
#              using s5cmd. It resolves S3 endpoints from a dynamic configuration registry 
#              using a numbered index system. The utility features automatic workspace creation 
#              and placeholder marker file fallback routines, alongside an optional 
#              post-upload source sanitation mechanism.
#
# @param       $1  [Required] Local file system path of the source payload file to ingest.
# @param       $2  [Required] S3 bucket target location pathway to write the payload.
# @param       $3  [Required] Post-upload local sanitation flag ("yes" to purge source, "no" to retain).
# @param       $4  [Required] Integer configuration ID used to select the targeted s5cmd profile suffix.
#
# @env         None explicitly sourced from top-level environment registers.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - /usr/bin/s5cmd high-performance storage integration software utility.
#              - /root/.s5cfg-${count} targeted credentials and cluster configuration file.
#
# @security    
#              - Restricts validation actions strictly to isolated tenant access keys inside config spaces.
#              - Safely caps directory tracking mutations by scrubbing trailing "root" overrides from the S3 namespace.
#              - Suppresses downstream standard error channels (`2>/dev/null`) to block credential exposure.
#              - Relies on system-owned executable paths (/bin, /usr/bin) to circumvent malicious search path injection.
#
# @exit        0  Success: Local payload safely transmitted and synchronized with the S3 datastore destination.
# @exit        1  Failure: Missing mandatory parameters or s5cmd execution driver failure.
###################################################################################
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

filename="${file_to_put_with_path##*/}"
place_to_put="${place_to_put%/}"

cfg_file="/root/.s5cfg-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" cp "$file_to_put_with_path" "s3://${place_to_put}/${filename}" 2>/dev/null
s5cmd_status=$?
set -e

if [ $s5cmd_status -ne 0 ]
then
    /bin/echo "Failed to put ${filename} to s3://${place_to_put}"
    status "s5cmd failed to upload ${filename} to s3://${place_to_put} (Exit code: $s5cmd_status)"
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
