#!/bin/sh
#: Name:        PerformDeleteFromDatastore.sh
#: Purpose:     Deletes an individual S3 object or wildcard tree via s5cmd using a targeted cluster profile.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       PerformDeleteFromDatastore.sh <file_to_delete> <count>
#:              PerformDeleteFromDatastore.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] S3 bucket target pathway and specific object key to delete (appending "root" enables trailing "*" wildcard purge)
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
#:   0          Target S3 object or wildcard tree deleted successfully
#:   1          Missing configuration, invalid arguments, missing s5cmd profile, or deletion failure
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
        /bin/echo "Usage: $0 <file_to_delete> <count>" >&2
        status "Error: Script invoked with missing arguments."
        exit 1
fi

file_to_delete="${1}"
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

# Check for trailing "root" suffix to enable wildcard deletion
wildcard=""
if [ "${file_to_delete%root}" != "${file_to_delete}" ]
then
        file_to_delete="${file_to_delete%root}"
        wildcard="*"
fi

# Delete the target S3 object or wildcard tree via s5cmd
status "Deleting S3 object 's3://${file_to_delete}${wildcard}' via profile ${count}..." "no"
set +e
/usr/bin/s5cmd --credentials-file "${cfg_file}" --endpoint-url "https://${host_base}" rm "s3://${file_to_delete}${wildcard}" >/dev/null 2>&1
s5cmd_status=$?
set -e

if [ "${s5cmd_status}" -ne 0 ]
then
        /bin/echo "Failed to delete file ${file_to_delete} from datastore" >&2
        status "Error: s5cmd failed to remove s3://${file_to_delete}${wildcard} (Exit code: ${s5cmd_status})"
        exit 1
fi

status "Success! Deleted S3 object 's3://${file_to_delete}${wildcard}' on profile ${count}." "no"
exit 0


