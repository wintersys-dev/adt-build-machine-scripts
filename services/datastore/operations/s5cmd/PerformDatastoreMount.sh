#!/bin/sh
#: Name:        PerformDatastoreMount.sh
#: Purpose:     Provisions or verifies an S3 bucket namespace via s5cmd using a targeted cluster profile.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       PerformDatastoreMount.sh <datastore_to_mount> <count>
#:              PerformDatastoreMount.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target S3 bucket name namespace to verify or provision
#:   $2         [Required] Integer configuration ID selecting the s5cmd profile suffix (/root/.s5cfg-<count>)
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - /root/.s5cfg-<count>
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut, awk, tr, s5cmd
#:
#: Exit Codes:
#:   0          Target S3 bucket verified or provisioned successfully
#:   1          Missing configuration, invalid arguments, missing s5cmd profile, or bucket creation failure
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
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
####################################################################################

# Exit immediately if any command exits with a non-zero status
#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the system tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Validate mandatory positional parameters
if [ -z "${1}" ] || [ -z "${2}" ]
then
        /bin/echo "Error: 2 arguments are required." >&2
        /bin/echo "Usage: $0 <datastore_to_mount> <count>" >&2
        status "Error: Script invoked with missing arguments."
        exit 1
fi

datastore_to_mount="${1}"
count="${2}"

# Validate that s5cmd binary and target configuration profile exist
if [ ! -x /usr/bin/s5cmd ]
then
        status "Error: Required binary /usr/bin/s5cmd missing or not executable."
        exit 1
fi

cfg_file="/root/.s5cfg-${count}"
if [ ! -r "${cfg_file}" ]
then
        /bin/echo "Error: Configuration profile ${cfg_file} not found." >&2
        status "Error: Profile configuration file missing or unreadable at ${cfg_file}"
        exit 1
fi

# Extract and validate the S3 host_base from the s5cmd configuration profile
host_base="$(/usr/bin/grep "^host_base" "${cfg_file}" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ' || true)"
if [ -z "${host_base}" ]
then
        status "Error: Failed to extract host_base from ${cfg_file}"
        exit 1
fi

# Check whether the target S3 bucket already exists; create it if missing
set +e
/usr/bin/s5cmd --credentials-file "${cfg_file}" --endpoint-url "https://${host_base}" head "s3://${datastore_to_mount}" >/dev/null 2>&1
check_status=$?

if [ "${check_status}" -ne 0 ]
then
        status "Creating S3 bucket 's3://${datastore_to_mount}' via profile ${count}..."
        /usr/bin/s5cmd --credentials-file "${cfg_file}" --endpoint-url "https://${host_base}" mb "s3://${datastore_to_mount}" >/dev/null 2>&1
        mb_status=$?

        if [ "${mb_status}" -ne 0 ]
        then
                /bin/echo "Failed to mount bucket s3://${datastore_to_mount}" >&2
                status "Error: s5cmd failed to create bucket s3://${datastore_to_mount} (Exit code: ${mb_status})"
                exit 1
        fi
fi
set -e

status "Success! Verified/mounted S3 bucket 's3://${datastore_to_mount}' on profile ${count}." "no"
exit 0




