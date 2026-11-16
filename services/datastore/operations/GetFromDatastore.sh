#!/bin/sh
#: Name:        GetFromDatastore.sh
#: Purpose:     Resolves target S3 bucket naming topologies by classification and retrieves a specific object from the primary datastore.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       GetFromDatastore.sh <bucket_type> <file_to_get> <destination> [additional_specifier]
#:              GetFromDatastore.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target bucket classification type (e.g., ssl, config, asset, backup-web, backup-db, ad-hoc)
#:   $2         [Required] Specific file name or relative object path within the bucket to retrieve
#:   $3         [Required] Local directory path or target destination filename
#:   $4         [Optional] Contextual tracking suffix or explicit bucket name for "ad-hoc" mode
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/services/datastore/operations/<datastore_tool>/PerformGetFromDatastore.sh
#:   - External binaries: cat, echo, grep, cut, sed, awk, fold, head, tr
#:
#: Exit Codes:
#:   0          Datastore object target resolution and retrieval completed successfully
#:   1          Missing configuration, invalid arguments, unsupported bucket type, or retrieval failure
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
        status "Error: 3 required arguments (<bucket_type> <file_to_get> <destination>) and 1 optional argument ([additional_specifier]) expected."
        exit 1
fi

bucket_type="${1}"
file_to_get="${2}"
destination="${3}"
additional_specifier="${4}"

# Retrieve required deployment context variables
WEBSITE_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" WEBSITE_URL)"
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"
SSL_GENERATION_SERVICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SSL_GENERATION_SERVICE)"
SERVER_USER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SERVER_USER)"

if [ -z "${WEBSITE_URL}" ]
then
        status "Error: Failed to fetch required context variable WEBSITE_URL."
        exit 1
fi

TOKEN="$(/bin/echo "${SERVER_USER}" | /usr/bin/fold -w 4 | /usr/bin/head -n 1 | /usr/bin/tr '[:upper:]' '[:lower:]')"

resolver_script="${BUILD_HOME}/services/datastore/operations/ResolveBucketName.sh"
if [ ! -f "${resolver_script}" ] || [ ! -x "${resolver_script}" ]
then
        status "Error: Bucket resolver script missing or not executable at ${resolver_script}"
        exit 1
fi

active_bucket="$("${resolver_script}" "${bucket_type}" "${additional_specifier}")"

# Resolve the active datastore tool from software.dat and validate its object retrieval driver
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -r "${software_file}" ]
then
        status "Error: Software configuration file missing or unreadable at ${software_file}"
        exit 1
fi

datastore_tool="$(/usr/bin/grep "^DATASTORETOOL:" "${software_file}" | /usr/bin/awk -F':' '{print $2}' || true)"
if [ -z "${datastore_tool}" ]
then
        status "Error: DATASTORETOOL is not defined in ${software_file}"
        exit 1
fi

get_object_driver="${BUILD_HOME}/services/datastore/operations/${datastore_tool}/PerformGetFromDatastore.sh"
if [ ! -f "${get_object_driver}" ] || [ ! -x "${get_object_driver}" ]
then
        status "Error: Datastore object retrieval driver missing or not executable at ${get_object_driver}"
        exit 1
fi

target_object="${active_bucket}/${file_to_get}"

status "Retrieving datastore object '${target_object}' to '${destination}'..." "no"
"${get_object_driver}" "${target_object}" "${destination}"

status "Success! Completed datastore object retrieval for '${target_object}'." "no"
exit 0



