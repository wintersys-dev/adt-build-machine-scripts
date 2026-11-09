#!/bin/sh
###################################################################################
# @file        create_instance.sh
# @brief       Provisions a secure Linode server instance with custom interfaces and metadata.
# @author      Peter Winter
# @date        09/11/2026
# @version     1.0
#
# @details     This script extracts deployment configuration metadata from a single input
#              payload string, loads environmental context via toolkit services,
#              securely handles or generates root emergency passwords, creates complex 
#              JSON interface schemas, and leverages the linode-cli interface to 
#              safely spin up a disk-encrypted cloud compute resource.
#
# @param       $1  [Required] Space-separated deployment parameters payload string:
#                  "region image server_size server_name firewall_id subnet_id user_data_path"
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh helper service querying contextual framework variables.
#              - external dependencies: cat, echo, tr, cut, openssl, jq, base64, linode-cli
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin, /usr/local/bin) to negate hijacking.
#              - Avoids unsafe temporary text config leaks by pushing metadata dynamically.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#              - Restricts process execution visibility of plain credentials where possible.
#
# @exit        0  Success: Cloud instance provisioned and registered seamlessly.
# @exit        *  Failure: Missing arguments, runtime payload extraction faults, 
#                 unreadable dependent runtime folders, or linode-cli validation drops.
##################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
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
set -e

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Verify stdin is a pipe or a redirected file, not a terminal
if [ -t 0 ]
then
        status "Error: Deployment parameters must be piped via stdin to protect process trees."
        exit 1
fi

# Read the single-line payload from standard input safely
if ! read -r parameter_payload
then
        status "Error: Failed to read deployment payload from stdin."
        exit 1
fi

set -- $parameter_payload

region="${1}"
image="${2}"
server_size="${3}"
server_name="${4}"
firewall_id="${5}"
subnet_id="${6}"
user_data_path="${7}"


# Ensure all expected payload arguments extracted successfully and are not empty
if [ -z "${region}" ] || [ -z "${image}" ] || [ -z "${server_size}" ] || [ -z "${server_name}" ] || [ -z "${firewall_id}" ] || [ -z "${subnet_id}" ] || [ -z "${user_data_path}" ]
then
        status "Error: Missing required fields in deployment parameter payload."
        exit 1
fi

# Validate existence and accessibility of the user data script file before proceeding
if [ ! -f "${user_data_path}" ] || [ ! -r "${user_data_path}" ]
then
        status "Error: Cannot read user data script at ${user_data_path}"
        exit 1
fi

CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ] || [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (CLOUDHOST, BUILD_IDENTIFIER, or TOKEN)."
        exit 1
fi

export LINODE_CLI_TOKEN="${TOKEN}"

# Set up and isolate runtime host state tracking hierarchy
runtime_dir="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
if [ ! -d "${runtime_dir}" ]
then
        /bin/mkdir -p "${runtime_dir}"
fi

password_file="${runtime_dir}/EMERGENCY_PASSWORD"
if [ ! -f "${password_file}" ]
then
        # Safely generate an alphanumeric random password sequence
        emergency_password="$(/usr/bin/openssl rand -base64 32 2>/dev/null | /bin/tr -d '\n' | /bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -c 1-16)"
        /bin/echo "${emergency_password}" > "${password_file}"
        /bin/chmod 600 "${password_file}"
fi

# Build secure JSON structures safely decoupling parameter strings via jq arguments
interfaces="$(/usr/bin/jq -n -c --arg fw_id "${firewall_id}" --arg sub_id "${subnet_id}" '[ { "firewall_id": ($fw_id | tonumber), "vpc": { "subnet_id": ($sub_id | tonumber), "ipv4": { "addresses": [ { "address": "auto", "nat_1_1_address": "auto" } ] } } } ]' 2>/dev/null)"

if [ -z "${interfaces}" ]
then
        status "Error: Failed to construct valid interfaces JSON structure."
        exit 1
fi

# Base64 encode the user data profile string securely
#encoded_user_data="$(/usr/bin/base64 < "${user_data_path}" | /bin/tr -d '\n')"

#if [ -z "${encoded_user_data}" ]
#then
#        status "Error: Failed to process or encode user data at ${user_data_path}"
#        exit 1
#fi

# Dispatch orchestration provisioning statement to the remote infrastructure client provider
set +e
/usr/local/bin/linode-cli --json linodes create --region "${region}" --type "${server_size}" --label "${server_name}" --image "${image}" --interface_generation linode --interfaces "${interfaces}" --root_pass "$(/bin/cat "${password_file}")" --metadata.user_data "$(/usr/bin/base64 < "${user_data_path}" | /bin/tr -d '\n')" --disk_encryption "enabled"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Error: linode-cli instance creation failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

status "Success: Linode instance ${server_name} successfully initialized."
exit 0
