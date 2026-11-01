#!/bin/sh
###################################################################################
# @file        PerformListFromDatastore.sh
# @brief       Automated S3 Datastore Existence Checker for Buckets and Objects.
# @author      Peter Winter
# @date        09/04/2021 (Updated 2026)
# @version     1.2
#
# @details     This script automates checking the existence of an entire bucket or 
#              a specific object file inside targeted cloud datastores using s5cmd info.
#              It intercepts exit codes to output an explicit confirmation status.
#
# @param       $1  [Required] Target S3 bucket name (e.g. "my-bucket") or file path.
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
    status "Usage: $0 <target_to_check>"
    status "Script invoked with missing arguments."
    exit 1
fi

target_to_check="$1"

cfg_file="/root/.s5cfg-1"
if [ ! -f "$cfg_file" ]
then
    status "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

# 2. Format the target S3 path correctly
s3_path="s3://${target_to_check}"

set +e
# 3. Query the endpoint using a silent info operation
/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" info "$s3_path" > /dev/null 2>&1
s5cmd_status=$?
set -e

# 4. Evaluate the status code to report existence
if [ $s5cmd_status -eq 0 ]
then
    /bin/echo "Target [${target_to_check}] exists in the datastore."
    exit 0
else
    /bin/echo "Target [${target_to_check}] does not exist (or is inaccessible)."
    exit 1
fi
