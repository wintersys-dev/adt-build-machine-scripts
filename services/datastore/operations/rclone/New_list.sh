#!/bin/sh 
###################################################################################
# @file        PerformExistenceCheck.sh
# @brief       Automated S3 Datastore Existence Tester for Buckets and Objects.
# @author      Peter Winter
# @date        09/04/2021 (Updated 2026)
# @version     1.1
#
# @details     This script verifies the absolute existence of a target bucket or specific
#              file path using rclone lsf metadata probing. It suppresses output contents
#              entirely, mapping the underlying exit statuses to a clean confirmation message.
#
# @param       $1  [Required] Target S3 bucket name or specific bucket/file pathway.
###################################################################################
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
    /bin/echo "Usage: $0 <target_to_check>"
    status "Script invoked with missing arguments."
    exit 1
fi

target_to_check="$1"

# Strip wildcard markers defensively
target_to_check=$(/bin/echo "$target_to_check" | /usr/bin/tr -d '*')

cfg_file="/root/.config/rclone/rclone.conf-1"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^endpoint "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
# 2. Query the endpoint using lsf (list files) limited to a depth of 1, muting all output
/usr/bin/rclone --config "$cfg_file" --s3-endpoint "$host_base" lsf "s3:${target_to_check}" --max-depth 1 >/dev/null 2>&1
rclone_status=$?
set -e

# 3. Handle confirmation logic based on the command exit status
if [ $rclone_status -eq 0 ]
then
    /bin/echo "Target [s3:${target_to_check}] exists in the datastore."
    exit 0
else
    /bin/echo "Target [s3:${target_to_check}] does not exist (or is inaccessible)."
    status "rclone existence check failed for s3:${target_to_check} (Exit code: $rclone_status)"
    exit 1
fi
