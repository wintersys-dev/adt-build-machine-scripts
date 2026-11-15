#!/bin/sh
#: Name:        create_instance.sh
#: Purpose:     Provisions a secure Linode server instance via linode-cli with VPC interfaces.
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
#:   - External binaries: cat, echo, grep, cut, tr, openssl, jq, base64, linode-cli
#:
#: Exit Codes:
#:   0          Cloud instance provisioned and registered seamlessly
#:   1          Missing stdin payload, layout faults, or context variable errors
#:   *          Bubbled exit code from linode-cli
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

# Route status log entries strictly to stderr so stdout remains clean JSON for callers
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
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

# Retrieve active deployment identifiers and cloud provider authentication token
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ] || [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (CLOUDHOST, BUILD_IDENTIFIER, or TOKEN)."
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

# Construct the VPC and firewall network interface JSON array safely via jq
interfaces="$(/usr/bin/jq -n -c --arg fw_id "${firewall_id}" --arg sub_id "${subnet_id}" '[ { "firewall_id": ($fw_id | tonumber), "vpc": { "subnet_id": ($sub_id | tonumber), "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ]' 2>/dev/null)"

if [ -z "${interfaces}" ]
then
        status "Error: Failed to construct valid interfaces JSON structure."
        exit 1
fi

# Base64-encode the cloud-init userdata file into a single line
encoded_user_data="$(/usr/bin/base64 < "${user_data_path}" | /bin/tr -d '\n')"

if [ -z "${encoded_user_data}" ]
then
        status "Error: Failed to process or encode user data at ${user_data_path}"
        exit 1
fi

# Export the API token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Dispatch instance creation via linode-cli with errexit paused to capture its exit code
set +e
/usr/local/bin/linode-cli --no-defaults --json linodes create \
        --region "${region}" \
        --type "${server_size}" \
        --label "${server_name}" \
        --image "${image}" \
        --interface_generation linode \
        --interfaces "${interfaces}" \
        --root_pass "${emergency_password}" \
        --metadata.user_data "${encoded_user_data}" \
        --disk_encryption "enabled"
exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI call finishes
unset LINODE_CLI_TOKEN

# Bubble up any non-zero exit code returned by linode-cli
if [ "${exit_code}" -ne 0 ]
then
        status "Error: linode-cli instance creation failed with exit code ${exit_code}."
        exit "${exit_code}"
fi

status "Success: Linode instance ${server_name} successfully initialized."
exit 0

