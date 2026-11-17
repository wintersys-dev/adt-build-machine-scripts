#!/bin/sh
#: Name:        PerformPutToDatastore.sh
#: Purpose:     Uploads a local file or virtual marker payload to an S3 datastore via s3cmd using a targeted cluster profile, with optional post-upload local cleanup.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       PerformPutToDatastore.sh <file_to_put> <place_to_put> <delete> <count>
#:              PerformPutToDatastore.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Local file path of the source payload to upload (creates a placeholder marker file if not found locally)
#:   $2         [Required] S3 bucket target location pathway (trailing "root" suffix is stripped)
#:   $3         [Required] Post-upload local cleanup flag ("yes" to delete local source, "no" to retain)
#:   $4         [Required] Integer configuration ID selecting the s3cmd profile suffix (/root/.s3cfg-<count>)
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:   HOME       Used to locate ${HOME}/runtime/datastore_workarea for placeholder marker files
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - /root/.s3cfg-<count>
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut, awk, tr, mkdir, touch, rm, basename, dirname, s3cmd
#:
#: Exit Codes:
#:   0          Local or virtual payload uploaded and synchronised successfully
#:   1          Missing configuration, invalid arguments, missing s3cmd profile, or upload failure
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
set -x
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
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"  "${2}"  2>/dev/null
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

# Validate that s3cmd binary and target configuration profile exist
if [ ! -x /usr/bin/s3cmd ]
then
        status "Error: Required binary /usr/bin/s3cmd missing or not executable."
        exit 1
fi

cfg_file="/root/.s3cfg-${count}"
if [ ! -r "${cfg_file}" ]
then
        /bin/echo "Error: Configuration profile ${cfg_file} not found." >&2
        status "Error: Profile configuration file missing or unreadable at ${cfg_file}"
        exit 1
fi

# Extract and validate the S3 host_base from the s3cmd configuration profile
host_base="$(/usr/bin/grep "^host_base" "${cfg_file}" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ' || true)"
if [ -z "${host_base}" ]
then
        status "Error: Failed to extract host_base from ${cfg_file}"
        exit 1
fi

# Upload the source payload to the target S3 path via s3cmd
status "Uploading '${file_to_put}' to 's3://${place_to_put}' via profile ${count}..." "no"
set +e
/usr/bin/s3cmd --config="${cfg_file}" --host="https://${host_base}" put "${file_to_put}" "s3://${place_to_put}" >/dev/null 2>&1
s3cmd_status=$?
set -e

if [ "${s3cmd_status}" -ne 0 ]
then
        /bin/echo "Failed to put ${file_to_put} to s3://${place_to_put}" >&2
        status "Error: s3cmd failed to upload ${file_to_put_with_path} to s3://${place_to_put} (Exit code: ${s3cmd_status})"
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

status "Success! Uploaded '${file_to_put}' to 's3://${place_to_put}' on profile ${count}." "no"
exit 0


