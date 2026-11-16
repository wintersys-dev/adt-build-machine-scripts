#!/bin/sh
#: Name:        PerformPutToDatastore.sh
#: Purpose:     Uploads a local file or directory to an S3 datastore via rclone using a targeted cluster profile, with optional post-upload local cleanup.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       PerformPutToDatastore.sh <file_to_put> <place_to_put> <delete> <count>
#:              PerformPutToDatastore.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Local file or directory path of the source payload to upload
#:   $2         [Required] S3 bucket target location pathway (trailing "root" suffix is stripped)
#:   $3         [Required] Post-upload local cleanup flag ("yes" to delete local source, "no" to retain)
#:   $4         [Required] Integer configuration ID selecting the rclone profile suffix (/root/.config/rclone/rclone.conf-<count>)
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - /root/.config/rclone/rclone.conf-<count>
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut, awk, tr, rm, rclone
#:
#: Exit Codes:
#:   0          Local payload uploaded and synchronised successfully
#:   1          Missing configuration, invalid arguments, missing source/profile, or upload failure
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
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        /bin/echo "Error: 4 arguments are required." >&2
        /bin/echo "Usage: $0 <file_to_put> <place_to_put> <delete> <count>" >&2
        status "Error: Script invoked with missing arguments."
        exit 1
fi

file_to_put="${1}"
place_to_put="${2}"
delete="${3}"
count="${4}"

# Strip trailing "root" suffix from target bucket path if present
place_to_put="${place_to_put%root}"

# Validate that the local source payload exists
if [ ! -e "${file_to_put}" ]
then
        /bin/echo "Error: Source payload ${file_to_put} does not exist." >&2
        status "Error: Source payload missing at ${file_to_put}"
        exit 1
fi

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

# Upload the source payload to the target S3 path via rclone
status "Uploading '${file_to_put}' to 's3:${place_to_put}' via profile ${count}..." "no"
set +e
/usr/bin/rclone --config "${cfg_file}" --s3-endpoint "${host_base}" copy "${file_to_put}" "s3:${place_to_put}" >/dev/null 2>&1
rclone_status=$?
set -e

if [ "${rclone_status}" -ne 0 ]
then
        /bin/echo "Failed to put ${file_to_put} to s3://${place_to_put}" >&2
        status "Error: rclone failed to upload ${file_to_put} to s3:${place_to_put} (Exit code: ${rclone_status})"
        exit 1
fi

# Optionally remove local source file after successful upload
if [ "${delete}" = "yes" ]
then
        if [ -f "${file_to_put}" ]
        then
                /bin/rm -f "${file_to_put}"
        fi
fi

status "Success! Uploaded '${file_to_put}' to 's3:${place_to_put}' on profile ${count}." "no"
exit 0

