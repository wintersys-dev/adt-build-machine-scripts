#!/bin/sh
#: Name:        MoveDatastoreObject.sh
#: Purpose:     Resolves target S3 bucket naming topologies by classification and moves, copies, or renames an object locally or across distributed nodes.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       MoveDatastoreObject.sh <bucket_type> <original_object> <new_object> <mode> [additional_specifier]
#:              MoveDatastoreObject.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Target bucket classification type (e.g., ssl, config, asset, backup-web, backup-db, ad-hoc)
#:   $2         [Required] Source object path within the target S3 bucket
#:   $3         [Required] Destination object path or new filename within the target S3 bucket
#:   $4         [Required] Execution topology mode ("local" or "distributed")
#:   $5         [Optional] Contextual tracking suffix or explicit bucket name for "ad-hoc" mode
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/services/datastore/operations/<datastore_tool>/PerformMoveDatastoreObject.sh
#:   - External binaries: cat, echo, grep, cut, sed, awk, wc
#:
#: Exit Codes:
#:   0          Datastore object target resolution and move completed successfully
#:   1          Missing configuration, invalid arguments, unsupported bucket/mode, or move failure
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
        status "Error: 4 required arguments (<bucket_type> <original_object> <new_object> <mode>) and 1 optional argument ([additional_specifier]) expected."
        exit 1
fi

bucket_type="${1}"
original_object="${2}"
new_object="${3}"
mode="${4}"
additional_specifier="${5}"

# Validate topology mode argument
if [ "${mode}" != "local" ] && [ "${mode}" != "distributed" ]
then
        status "Error: Invalid topology mode '${mode}'. Must be 'local' or 'distributed'."
        exit 1
fi

# Retrieve required deployment context variables
S3_ACCESS_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" S3_ACCESS_KEY)"
WEBSITE_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" WEBSITE_URL)"
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"
SSL_GENERATION_SERVICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" SSL_GENERATION_SERVICE)"

if [ -z "${S3_ACCESS_KEY}" ] || [ -z "${WEBSITE_URL}" ]
then
        status "Error: Failed to fetch required context variables (S3_ACCESS_KEY or WEBSITE_URL)."
        exit 1
fi

# Construct the target bucket name based on bucket classification
case "${bucket_type}" in
        "ssl")
                if [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
                then
                        service_token="lets"
                elif [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
                then
                        service_token="zero"
                else
                        status "Error: Unsupported or empty SSL_GENERATION_SERVICE '${SSL_GENERATION_SERVICE}'."
                        exit 1
                fi
                active_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-${DNS_CHOICE}-${service_token}-ssl"
                ;;
        "auth-ssl")
                AUTH_SERVER_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" AUTH_SERVER_URL)"
                AUTH_DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" AUTH_DNS_CHOICE)"
                if [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
                then
                        service_token="lets"
                elif [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
                then
                        service_token="zero"
                else
                        status "Error: Unsupported or empty SSL_GENERATION_SERVICE '${SSL_GENERATION_SERVICE}'."
                        exit 1
                fi
                active_bucket="$(/bin/echo "${AUTH_SERVER_URL}" | /bin/sed 's/\./-/g')-${AUTH_DNS_CHOICE}-${service_token}-ssl"
                ;;
        "multi-region")
                active_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-multi-region"
                ;;
        "config")
                active_bucket="$(/bin/echo "${WEBSITE_URL}-config" | /bin/sed 's/\./-/g')-${additional_specifier}"
                ;;
        "auth-config")
                AUTH_SERVER_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" AUTH_SERVER_URL)"
                active_bucket="$(/bin/echo "${AUTH_SERVER_URL}-config" | /bin/sed 's/\./-/g')-${additional_specifier}"
                ;;
        "asset")
                active_bucket="$(/bin/echo "${WEBSITE_URL}-assets-${additional_specifier}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g')"
                ;;
        "scaling"|"backup-web")
                active_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-${additional_specifier}"
                ;;
        "firewall-auth-laptop-ips"|"whitelist-auth-laptop-ips"|"firewall-emailed-links"|"whitelist-emailed-links"|"basic-auth-credentials")
                active_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-${bucket_type}"
                ;;
        "wire-guard")
                active_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-wireguard"
                ;;
        "wire-guard-emails")
                active_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-wireguard-emails"
                ;;
        "wire-guard-emailed-links")
                active_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-wireguard-emailed-links"
                ;;
        "backup-db")
                active_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-db-${additional_specifier}"
                ;;
        "auth")
                active_bucket="authip-adt-allowed-${additional_specifier}"
                ;;
        "dbaas")
                active_bucket="$(/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g')-${DNS_CHOICE}-dbaas"
                ;;
        "ad-hoc")
                active_bucket="${additional_specifier}"
                ;;
        *)
                status "Error: Unknown bucket classification type '${bucket_type}'."
                exit 1
                ;;
esac

if [ -z "${active_bucket}" ]
then
        status "Error: Resolved target bucket name is empty for classification '${bucket_type}'."
        exit 1
fi

# Resolve the active datastore tool from software.dat and validate its object move driver
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

move_object_driver="${BUILD_HOME}/services/datastore/operations/${datastore_tool}/PerformMoveDatastoreObject.sh"
if [ ! -f "${move_object_driver}" ] || [ ! -x "${move_object_driver}" ]
then
        status "Error: Datastore object move driver missing or not executable at ${move_object_driver}"
        exit 1
fi

# Count the number of pipe-delimited S3 providers configured
pipe_count="$(/bin/echo "${S3_ACCESS_KEY}" | /usr/bin/grep -Fo '|' | /usr/bin/wc -l || true)"
no_tokens=$((pipe_count + 1))
count=1

source_path="${active_bucket}/${original_object}"
dest_path="${active_bucket}/${new_object}"

# Execute datastore object move locally (node 1) or across all distributed S3 nodes
if [ "${mode}" = "local" ]
then
        status "Moving datastore object '${source_path}' to '${dest_path}' in local mode (node 1)..."
        "${move_object_driver}" "${source_path}" "${dest_path}" "${count}"
elif [ "${mode}" = "distributed" ]
then
        while [ "${count}" -le "${no_tokens}" ]
        do
                status "Moving datastore object '${source_path}' to '${dest_path}' on node ${count} of ${no_tokens}..."
                "${move_object_driver}" "${source_path}" "${dest_path}" "${count}"
                count=$((count + 1))
        done
fi

status "Success! Completed datastore object move from '${source_path}' to '${dest_path}'."
exit 0


