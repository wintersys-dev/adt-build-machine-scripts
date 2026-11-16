#!/bin/sh
#: Name:        PerformMoveDatastoreObject.sh
#: Purpose:     Moves or renames an S3 object server-side via rclone using a targeted cluster profile.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       PerformMoveDatastoreObject.sh <original_object> <new_object> <count>
#:              PerformMoveDatastoreObject.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Source S3 bucket pathway and object key to relocate
#:   $2         [Required] Destination S3 bucket pathway and target object key
#:   $3         [Required] Integer configuration ID selecting the rclone profile suffix (/root/.config/rclone/rclone.conf-<count>)
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - /root/.config/rclone/rclone.conf-<count>
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut, awk, tr, rclone
#:
#: Exit Codes:
#:   0          Target S3 object moved or renamed successfully
#:   1          Missing configuration, invalid arguments, missing rclone profile, or move failure
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
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        /bin/echo "Error: 3 arguments are required." >&2
        /bin/echo "Usage: $0 <original_object> <new_object> <count>" >&2
        status "Error: Script invoked with missing arguments."
        exit 1
fi

original_object="${1}"
new_object="${2}"
count="${3}"

# Validate that rclone binary and target configuration profile exist
if [ ! -x /usr/bin/rclone ]
then
        status "Error: Required binary /usr/bin/rclone missing or not executable."
        exit 1
fi

cfg_file="/root/.config/rclone/rclone.conf-${count}"
if [ ! -r "${cfg_file}" ]
then
        /bin/echo "Error: Configuration profile ${cfg_file} not found." >&2
        status "Error: Profile configuration file missing or unreadable at ${cfg_file}"
        exit 1
fi

# Extract and validate the S3 endpoint URL from the rclone configuration profile
host_base="$(/usr/bin/grep "^endpoint" "${cfg_file}" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ' || true)"
if [ -z "${host_base}" ]
then
        status "Error: Failed to extract endpoint from ${cfg_file}"
        exit 1
fi

# Move or rename the target S3 object server-side via rclone
status "Moving S3 object 's3:${original_object}' to 's3:${new_object}' via profile ${count}..."
set +e
/usr/bin/rclone --config "${cfg_file}" --s3-endpoint "${host_base}" moveto "s3:${original_object}" "s3:${new_object}" >/dev/null 2>&1
rclone_status=$?
set -e

if [ "${rclone_status}" -ne 0 ]
then
        /bin/echo "Failed to move object ${original_object} to object ${new_object}" >&2
        status "Error: rclone failed to move object s3:${original_object} to s3:${new_object} (Exit code: ${rclone_status})"
        exit 1
fi

status "Success! Moved S3 object 's3:${original_object}' to 's3:${new_object}' on profile ${count}."
exit 0

