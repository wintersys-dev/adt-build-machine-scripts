#!/bin/sh
#: Name:        create_instance.sh
#: Purpose:     Provisions a Linode server instance directly via the Linode REST API v4.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       echo "<region> <image> <size> <name> <fw_id> <subnet_id> <userdata_path>" | create_instance.sh
#:              create_instance.sh [-h|--help]
#:
#: Parameters:
#:   stdin      [Required] Space-separated deployment parameters payload string:
#:                         "region image server_size server_name firewall_id subnet_id user_data_path"
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, tr, sed, openssl, jq, base64, curl
#:
#: Exit Codes:
#:   0          Cloud instance creation payload accepted by API server
#:   1          Missing stdin payload, layout faults, encoding failures, or non-2xx API status
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

# Verify stdin is a pipe or redirected file rather than an interactive terminal
if [ -t 0 ]
then
        status "Error: Deployment parameters must be piped via stdin to protect process trees."
        exit 1
fi

# Read the single-line deployment payload from standard input
if ! read -r parameter_payload
then
        status "Error: Failed to read deployment payload from stdin."
        exit 1
fi

# Unpack the space-delimited payload string into positional parameters
set -- ${parameter_payload}

region="${1}"
image="${2}"
server_size="${3}"
server_name="${4}"
firewall_id="${5}"
subnet_id="${6}"
user_data_path="${7}"

# Ensure all 7 expected payload fields are non-empty
if [ -z "${region}" ] || [ -z "${image}" ] || [ -z "${server_size}" ] || [ -z "${server_name}" ] || [ -z "${firewall_id}" ] || [ -z "${subnet_id}" ] || [ -z "${user_data_path}" ]
then
        status "Error: Missing required fields in deployment parameter payload."
        exit 1
fi

# Validate existence and readability of the cloud-init userdata file
if [ ! -f "${user_data_path}" ] || [ ! -r "${user_data_path}" ]
then
        status "Error: Cannot read user data script at ${user_data_path}"
        exit 1
fi

# Retrieve authentication token and active deployment identifiers
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"

if [ -z "${TOKEN}" ] || [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN, CLOUDHOST, or BUILD_IDENTIFIER)."
        exit 1
fi

# Ensure the runtime directory exists for storing the shared emergency root password
runtime_dir="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
if [ ! -d "${runtime_dir}" ]
then
        /bin/mkdir -p "${runtime_dir}"
fi

# Read the existing build emergency root password or generate a new 16-character alphanumeric one
password_file="${runtime_dir}/EMERGENCY_PASSWORD"
if [ -f "${password_file}" ]
then
        if [ ! -r "${password_file}" ]
        then
                status "Error: Password file exists but is unreadable at ${password_file}"
                exit 1
        fi
        emergency_password="$(/bin/cat "${password_file}")"
else
        emergency_password="$(/usr/bin/openssl rand -base64 32 2>/dev/null | /bin/tr -d '\n' | /bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -c 1-16)"
        /bin/echo "${emergency_password}" > "${password_file}"
        /bin/chmod 600 "${password_file}"
fi

if [ -z "${emergency_password}" ]
then
        status "Error: Emergency password variable isolation failed or resolved empty."
        exit 1
fi

# Base64-encode the cloud-init userdata file into a single line
user_data_encoded="$(/usr/bin/base64 < "${user_data_path}" | /bin/tr -d '\n')"

if [ -z "${user_data_encoded}" ]
then
        status "Error: Failed to process or encode user data at ${user_data_path}"
        exit 1
fi

# Construct the complete Linode instance JSON payload safely via jq
instance_payload="$(/usr/bin/jq -n -c --arg pass "${emergency_password}" --arg reg "${region}" --arg img "${image}" --arg size "${server_size}" --arg name "${server_name}" --arg fw "${firewall_id}" --arg sub "${subnet_id}" --arg ud "${user_data_encoded}" '{ root_pass: $pass, region: $reg, image: $img, type: $size, label: $name, interface_generation: "linode", interfaces: [ { firewall_id: ($fw | tonumber), vpc: { subnet_id: ($sub | tonumber), ipv4: { addresses: [ { address: "auto", nat_1_1_address: "auto" } ] } } } ], metadata: { user_data: $ud }, disk_encryption: "enabled" }' 2>/dev/null)"

if [ -z "${instance_payload}" ]
then
        status "Error: Failed to construct valid instance configuration JSON."
        exit 1
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/linode/instances"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Submit the instance creation POST request with token passed securely via stdin
set +e
RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -X POST "${endpoint}" -H "Content-Type: application/json" -d "${instance_payload}" -w "\nHTTP_STATUS:%{http_code}")
set -e

# Separate the HTTP status code and JSON response body
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate HTTP status code and handle API errors explicitly
case "${HTTP_CODE}" in
        200|201)
                status "Success! Linode instance created."
                /bin/echo "${RESPONSE_BODY}"
                ;;
        400)
                status "Error 400: Bad Request. Check your payload syntax."
                status "API Response: ${RESPONSE_BODY}"
                exit 1
                ;;
        401)
                status "Error 401: Unauthorized. Check your TOKEN."
                exit 1
                ;;
        403)
                status "Error 403: Forbidden. Missing permissions."
                exit 1
                ;;
        429)
                status "Error 429: Rate Limit Exceeded."
                exit 1
                ;;
        5*)
                status "Error ${HTTP_CODE}: Linode Server Error."
                exit 1
                ;;
        *)
                status "Error ${HTTP_CODE}: Unexpected response."
                status "API Response: ${RESPONSE_BODY}"
                exit 1
                ;;
esac

exit 0
