#!/bin/sh 
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S3 Datastore Object Purging, Tree Deletion, or Bucket Removal.
# @author      Peter Winter
# @date        09/04/2021 (Updated 2026)
# @version     1.1
#
# @details     This script automates data removal operations inside targeted cloud
#              datastores using rclone. It dynamically matches your target input path
#              to run 'delete' for files, 'delete --rmdirs' for directory trees, 
#              or 'purge' to completely eliminate an entire bucket structure.
#
# @param       $1  [Required] S3 target pathway (bucket name, file path, or folder tree ending in 'root').
# @param       $2  [Required] Integer configuration ID used to select the targeted rclone profile suffix.
###################################################################################
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
    /bin/echo "Usage: $0 <target_to_delete> <count>"
    status "Script invoked with missing arguments."
    exit 1
fi

target_to_delete="$1"
count="$2"

cfg_file="/root/.config/rclone/rclone.conf-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^endpoint "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

# Initialize default rclone command configurations
rclone_cmd="delete"
rmdirs=""

# 2. Determine deletion type based on input pattern
if [ "${target_to_delete%root}" != "$target_to_delete" ]
then
    # Case A: Folder tree wildcard deletion (ends in "root")
    target_to_delete="${target_to_delete%root}"
    rmdirs="--rmdirs"
elif [ "${target_to_delete%/*}" = "$target_to_delete" ]
then
    # Case B: Full bucket deletion (Input contains no slashes, meaning only a bucket name was passed)
    rclone_cmd="purge"
fi

set +e
# 3. Execute the appropriate rclone deletion operation
if [ -n "$rmdirs" ]
then
    /usr/bin/rclone --config "$cfg_file" --s3-endpoint "$host_base" "$rclone_cmd" "s3:${target_to_delete}" --rmdirs >/dev/null 2>&1
else
    /usr/bin/rclone --config "$cfg_file" --s3-endpoint "$host_base" "$rclone_cmd" "s3:${target_to_delete}" >/dev/null 2>&1
fi
rclone_status=$?
set -e

if [ $rclone_status -ne 0 ]
then
    /bin/echo "Failed to execute $rclone_cmd action on ${target_to_delete} from datastore"
    status "rclone failed action $rclone_cmd on s3:${target_to_delete} (Prune empty dirs: ${rmdirs:-no}, Exit code: $rclone_status)"
    exit 1
fi

exit 0
