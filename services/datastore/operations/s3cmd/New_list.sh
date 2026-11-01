#!/bin/sh 
###################################################################################
# @file        PerformListFromDatastore.sh
# @brief       Automated S3 Datastore Existence Tester for Buckets and Objects.
# @author      Peter Winter
# @date        09/04/2021 (Updated 2026)
# @version     1.1
#
# @details     This script checks the absolute existence of a target bucket or specific
#              file path using s3cmd info. It suppresses output contents entirely, mapping
#              the underlying exit statuses to a clean confirmation message.
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

cfg_file="/root/.s3cfg-1"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    status "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
# 2. Use s3cmd info to test for existence, throwing away all stdout and stderr
/usr/bin/s3cmd --config="$cfg_file" --host="https://${host_base}" info "s3://${target_to_check}" > /dev/null 2>&1
s3cmd_status=$?
set -e

# 3. Handle confirmation logic based on the command exit status
if [ $s3cmd_status -eq 0 ]
then
    /bin/echo "Target exists: [s3://${target_to_check}]"
    exit 0
else
    /bin/echo "Target does not exist (or is inaccessible): [s3://${target_to_check}]"
    status "s3cmd info failed for s3://${target_to_check} (Exit code: $s3cmd_status)"
    exit 1
fi
