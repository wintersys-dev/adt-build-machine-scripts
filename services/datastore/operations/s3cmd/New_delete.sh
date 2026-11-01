#!/bin/sh
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S3 Datastore Purging Driver for Files and Entire Buckets.
# @author      Peter Winter
# @date        09/04/2021 (Updated 2026)
# @version     1.2
#
# @details     This script automates data removal operations inside targeted cloud
#              datastores using s5cmd. It dynamically targets either a single
#              file path or an entire bucket structure depending on input context.
#
# @param       $1  [Required] Target S3 pathway (bucket name or bucket/file path).
###################################################################################
#set -x
set -e

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

status () {
    /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
    script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
    /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

# 1. Check for the 1 required argument safely
if [ -z "$1" ]
then
    status "Error: 1 argument is required."
    status "Usage: $0 <target_to_delete>"
    status "Script invoked with missing arguments."
    exit 1
fi

target_to_delete="$1"

cfg_file="/root/.s5cfg-1"
if [ ! -f "$cfg_file" ]
then
    status "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

# Initialize defaults
s5cmd_cmd="rm"
wildcard=""

# 2. Determine if target is a bucket or a file
# If the input contains no slashes, it is evaluated as an entire bucket
if [ "${target_to_delete%/*}" = "$target_to_delete" ]
then
    s5cmd_cmd="rb"
# Check if wildcard directory tree deletion was requested via 'root' suffix
elif [ "${target_to_delete%root}" != "$target_to_delete" ]
then
    target_to_delete="${target_to_delete%root}"
    wildcard="*"
fi

set +e
# 3. Execute the deletion operation (rm or rb)
/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" $s5cmd_cmd "s3://${target_to_delete}${wildcard}" 2>/dev/null
s5cmd_status=$?
set -e

if [ $s5cmd_status -ne 0 ]
then
    status "Failed to execute $s5cmd_cmd action on ${target_to_delete}"
    status "s5cmd failed to delete s3://${target_to_delete}${wildcard} (Exit code: $s5cmd_status)"
    exit 1
fi

status "Successfully deleted target: s3://${target_to_delete}${wildcard}"
exit 0
