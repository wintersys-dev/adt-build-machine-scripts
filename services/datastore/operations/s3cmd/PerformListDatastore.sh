#!/bin/sh
#: Name:        PerformListDatastore.sh
#: Purpose:     Lists all S3 datastore buckets or verifies a specific bucket namespace via s3cmd using the primary cluster profile.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       PerformListDatastore.sh <datastore_to_list>
#:              PerformListDatastore.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target S3 datastore bucket name to verify, or "all" to list all buckets
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - /root/.s3cfg-1
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut, awk, sed, tr, s3cmd
#:
#: Exit Codes:
#:   0          Target datastore bucket(s) listed or verified successfully
#:   1          Missing configuration, invalid arguments, missing s3cmd profile, or target datastore not found
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
if [ -z "${1}" ]
then
        /bin/echo "Error: 1 argument is required." >&2
        /bin/echo "Usage: $0 <datastore_to_list>" >&2
        status "Error: Script invoked with missing arguments."
        exit 1
fi

datastore_to_list="${1}"
# Validate that s3cmd binary and primary configuration profile exist
if [ ! -x /usr/bin/s3cmd ]
then
        status "Error: Required binary /usr/bin/s3cmd missing or not executable."
        exit 1
fi

cfg_file="/root/.s3cfg-1"
if [ ! -r "${cfg_file}" ]
then
        /bin/echo "Error: Configuration profile ${cfg_file} not found." >&2
        status "Error: Profile configuration file missing or unreadable at ${cfg_file}"
        exit 1
fi

# Extract and validate the S3 host_base from the primary s3cmd configuration profile
host_base="$(/usr/bin/grep "^host_base" "${cfg_file}" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ' || true)"
if [ -z "${host_base}" ]
then
        status "Error: Failed to extract host_base from ${cfg_file}"
        exit 1
fi

# Query S3 buckets via s3cmd
set +e
s3_raw_output="$(/usr/bin/s3cmd --config="${cfg_file}" --host="https://${host_base}" ls 2>/dev/null)"
s3cmd_status=$?
set -e

if [ "${s3cmd_status}" -ne 0 ]
then
        /bin/echo "Failed to list datastore: s3cmd command failed." >&2
        status "Error: Failed to list datastores due to s3cmd connection or configuration failure (Exit code: ${s3cmd_status})."
        exit 1
fi

parsed_list="$(/bin/echo "${s3_raw_output}" | /usr/bin/awk '{print $NF}' | /bin/sed -e 's|s3://||' -e 's|/.*||')"

if [ "${datastore_to_list}" = "all" ]
then
        /bin/echo "${parsed_list}"
else
        if ! /bin/echo "${parsed_list}" | /usr/bin/grep -Fx "${datastore_to_list}"
        then
                /bin/echo "Failed to list datastore: [${datastore_to_list}] not found." >&2
                status "Error: Failed to list datastore ${datastore_to_list}: element not found."
                exit 1
        fi
fi

exit 0

