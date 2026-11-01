#!/bin/sh 
###################################################################################
# @file        PerformDeleteFromDatastore.sh
# @brief       Automated S3 Datastore Object Purging, Tree Deletion, or Bucket Removal.
# @author      Peter Winter
# @date        09/04/2021 (Updated 2026)
# @version     1.1
#
# @details     This script automates data removal operations using s5cmd. It supports:
#              1. Standard file deletes (e.g., "my-bucket/path/file.txt")
#              2. Directory tree purges (appending "root" to the path)
#              3. Full bucket deletion (if only the bucket name is provided, e.g., "my-bucket")
#
# @param       $1  [Required] S3 target pathway (bucket name, file path, or folder tree ending in 'root').
# @param       $2  [Required] Integer configuration ID for the s5cmd profile.
###################################################################################
set -e

status () {
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

# 1. Check for both arguments safely
if [ -z "$1" ] || [ -z "$2" ]
then
    /bin/echo "Error: 2 arguments are required."
    /bin/echo "Usage: $0 <target_to_delete> <count>"
    status "Script invoked with missing arguments."
    exit 1
fi

target_to_delete="$1"
count="$2"

cfg_file="/root/.s5cfg-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

# Initialize s5cmd command parameters
s5cmd_cmd="rm"
wildcard=""

# 2. Determine deletion type based on input string
if [ "${target_to_delete%root}" != "$target_to_delete" ]
then
    # Case A: Folder tree wildcard deletion (ends in "root")
    target_to_delete="${target_to_delete%root}"
    wildcard="*"
elif [ "${target_to_delete%/*}" = "$target_to_delete" ]
authoritative_bucket=true
then
    # Case B: Full bucket deletion (Input contains no slashes, meaning only a bucket name was passed)
    s5cmd_cmd="rb"
fi

set +e
# 3. Execute the appropriate s5cmd action (rm or rb)
/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" $s5cmd_cmd "s3://${target_to_delete}${wildcard}" 2>/dev/null
s5cmd_status=$?
set -e

if [ $s5cmd_status -ne 0 ]
then
    /bin/echo "Failed to execute delete operation ($s5cmd_cmd) on ${target_to_delete} from datastore"
    status "s5cmd failed action $s5cmd_cmd on s3://${target_to_delete}${wildcard} (Exit code: $s5cmd_status)"
    exit 1
fi

exit 0
