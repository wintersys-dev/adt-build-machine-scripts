#!/bin/sh
#: Name:        InitialiseDatastoreConfigs.sh
#: Purpose:     Iterates through pipe-delimited S3 credentials and initialises datastore configurations for each provider.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       InitialiseDatastoreConfigs.sh
#:              InitialiseDatastoreConfigs.sh [-h|--help]
#:
#: Parameters:
#:   None
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/initialisation/InitialiseDatastoreConfig.sh
#:   - External binaries: cat, echo, grep, cut, wc, printf
#:
#: Exit Codes:
#:   0          All S3 datastore configurations initialised successfully
#:   1          Missing configuration, missing context variables/scripts, or initialisation failure
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

# Validate that the target datastore configuration script exists and is executable
datastore_script="${BUILD_HOME}/initialisation/InitialiseDatastoreConfig.sh"
if [ ! -f "${datastore_script}" ] || [ ! -x "${datastore_script}" ]
then
        status "Error: Target script missing or not executable at ${datastore_script}"
        exit 1
fi

# Retrieve pipe-delimited S3 configuration variables
S3_ACCESS_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" S3_ACCESS_KEY)"
S3_SECRET_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" S3_SECRET_KEY)"
S3_LOCATION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" S3_LOCATION)"
S3_HOST_BASE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" S3_HOST_BASE)"

if [ -z "${S3_ACCESS_KEY}" ] || [ -z "${S3_SECRET_KEY}" ] || [ -z "${S3_LOCATION}" ] || [ -z "${S3_HOST_BASE}" ]
then
        status "Error: Failed to fetch required S3 configuration variables (S3_ACCESS_KEY, S3_SECRET_KEY, S3_LOCATION, or S3_HOST_BASE)."
        exit 1
fi

# Count the number of pipe-delimited S3 providers configured
pipe_count="$(/usr/bin/printf '%s' "${S3_ACCESS_KEY}" | /usr/bin/grep -Fo '|' | /usr/bin/wc -l || true)"
no_tokens=$((pipe_count + 1))
count=1

# Iterate over each S3 credential set and invoke InitialiseDatastoreConfig.sh
while [ "${count}" -le "${no_tokens}" ]
do
        access_key="$(/usr/bin/printf '%s\n' "${S3_ACCESS_KEY}" | /usr/bin/cut -d '|' -f "${count}")"
        secret_key="$(/usr/bin/printf '%s\n' "${S3_SECRET_KEY}" | /usr/bin/cut -d '|' -f "${count}")"
        location="$(/usr/bin/printf '%s\n' "${S3_LOCATION}" | /usr/bin/cut -d '|' -f "${count}")"
        host_base="$(/usr/bin/printf '%s\n' "${S3_HOST_BASE}" | /usr/bin/cut -d '|' -f "${count}")"

        if [ -z "${access_key}" ] || [ -z "${secret_key}" ] || [ -z "${location}" ] || [ -z "${host_base}" ]
        then
                status "Error: Incomplete S3 configuration fields found at index ${count}."
                exit 1
        fi

        status "Initialising S3 datastore configuration ${count} of ${no_tokens} (${host_base})..."
        "${datastore_script}" "${access_key}" "${secret_key}" "${location}" "${host_base}" "${count}"

        count=$((count + 1))
done

status "Success! Initialised ${no_tokens} S3 datastore configuration(s)."
exit 0

