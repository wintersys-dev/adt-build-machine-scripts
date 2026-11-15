#!/bin/sh
#: Name:        ProvisionServer.sh
#: Purpose:     Orchestrates metadata preparation and triggers provider-specific instance deployment.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       ProvisionServer.sh <server_size> <server_name> <machine_type>
#:              ProvisionServer.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The targeted server hardware size plan / tier.
#:   $2         [Required] The human-readable label/hostname assigned to the server.
#:   $3         [Required] The structural type or architecture category of the machine.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - GetOperatingSystemVersion.sh
#:   - InitialiseCloudConfig.sh
#:   - ConfigureNativeFirewall.sh
#:   - ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST
#:   - ${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER
#:   - External binaries: cat, echo, grep, cut, sed, awk
#:
#: Exit Codes:
#:   0          Runtime options consolidated and server provisioner launched successfully
#:   1          Missing arguments, unreadable configurations, missing cloud-init YAML, or missing script
#:   *          Bubbled exit code from provider-specific ProvisionServer.sh
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

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Validate that all three required provisioning arguments were provided
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: 3 Server arguments are required."
        status "Usage: $0 <server_size> <server_name> <machine_type>"
        exit 1
fi

server_size="${1}"
server_name="${2}"
machine_type="${3}"

# Read and validate the active cloud provider identifier
cloudhost_file="${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST"
if [ ! -f "${cloudhost_file}" ] || [ ! -r "${cloudhost_file}" ]
then
        status "Error: Cannot read active cloud host file at ${cloudhost_file}"
        exit 1
fi

# Read and validate the active build run identifier
build_id_file="${BUILD_HOME}/runtime/ACTIVE_BUILD_IDENTIFIER"
if [ ! -f "${build_id_file}" ] || [ ! -r "${build_id_file}" ]
then
        status "Error: Cannot read active build identifier file at ${build_id_file}"
        exit 1
fi

CLOUDHOST="$(/bin/cat "${cloudhost_file}")"
BUILD_IDENTIFIER="$(/bin/cat "${build_id_file}")"

if [ -z "${CLOUDHOST}" ] || [ -z "${BUILD_IDENTIFIER}" ]
then
        status "Error: CLOUDHOST or BUILD_IDENTIFIER variable is empty."
        exit 1
fi

# Retrieve deployment parameters and resolve the provider-specific OS image slug
set +e
REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" REGION 2>/dev/null)"
WEBSITE_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" WEBSITE_URL 2>/dev/null)"
ACTIVE_FIREWALLS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" ACTIVE_FIREWALLS 2>/dev/null)"
BUILDOS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILDOS 2>/dev/null)"
BUILDOS_VERSION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILDOS_VERSION 2>/dev/null)"
BUILD_FROM_SNAPSHOT="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_FROM_SNAPSHOT 2>/dev/null)"
OS_CHOICE="$("${BUILD_HOME}/services/server/GetOperatingSystemVersion.sh" 2>/dev/null | /bin/sed "s/'//g")"
set -e

# Strip the 'adt-' prefix to derive the bare machine role category (e.g. webserver, database)
machine_category="$(/bin/echo "${machine_type}" | /bin/sed 's|adt-||')"

# Generate the node-specific cloud-init userdata YAML configuration
set +e
"${BUILD_HOME}/initialisation/cloud-init/InitialiseCloudConfig.sh" "${machine_category}" "${server_name}" 2>/dev/null
set -e

yaml_path="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/cloud-init/${machine_category}.yaml"
if [ -f "${yaml_path}" ]
then
        user_data="${yaml_path}"
else
        status "Cloud config file not found at ${yaml_path}"
        exit 1
fi

# Resolve a golden snapshot ID if snapshot-based deployment is enabled
snapshot_id=""
if [ "${BUILD_FROM_SNAPSHOT}" = "1" ]
then
        snapshot_file="${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/snapshot_ids.dat"
        if [ -f "${snapshot_file}" ]
        then
                snapshot_id="$(/bin/grep "${machine_category}" "${snapshot_file}" 2>/dev/null | /usr/bin/awk -F':' '{print $NF}')"
                status "Deploying ${machine_category} machine from snapshot with ID ${snapshot_id}"
        fi
fi

# Configure the native cloud firewall and capture its ID when native firewalls are active
firewall_id=""
if [ "${ACTIVE_FIREWALLS}" = "2" ] || [ "${ACTIVE_FIREWALLS}" = "3" ]
then
        set +e
        firewall_id="$("${BUILD_HOME}/services/security/firewall/ConfigureNativeFirewall.sh" "${machine_type}" 2>/dev/null | /bin/grep 'ADT_FIREWALL_ID:' | /usr/bin/awk -F':' '{print $NF}')"
        set -e
fi

# Default to -1 when no native cloud firewall ID applies
if [ -z "${firewall_id}" ]
then
        firewall_id="-1"
fi

# Override the base OS image with the golden snapshot ID when available
image="${OS_CHOICE}"
if [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -n "${snapshot_id}" ]
then
        image="${snapshot_id}"
fi

# Locate and verify execution permissions on the provider-specific server provisioner
script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/ProvisionServer.sh"

if [ ! -f "${script_path}" ]
then
        status "Error: Script not found at ${script_path}"
        exit 1
fi

if [ ! -x "${script_path}" ]
then
        status "Error: Script at ${script_path} is not executable."
        exit 1
fi

# Execute the provider-specific server provisioner with errexit paused to capture its exit code
set +e
"${script_path}" "${REGION}" "${image}" "${server_size}" "${server_name}" "${user_data}" "${firewall_id}" "${snapshot_id}"
exit_code="$?"
set -e

# Bubble up any non-zero exit code returned by the provider script
if [ "${exit_code}" -ne 0 ]
then
        status "Error: ProvisionServer.sh failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0

