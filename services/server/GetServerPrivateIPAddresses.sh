#!/bin/sh
#: Name:        GetServerPrivateIPAddresses.sh
#: Purpose:     Resolves active runtime paths and triggers provider-specific private IP lookup.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       GetServerPrivateIPAddressesMain.sh <server_type>
#:              GetServerPrivateIPAddressesMain.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique name or type label of the target machine.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Target handoff complete and server private IP resolved successfully
#:   1          Missing arguments, unreadable configurations, or missing provider script
#:   *          Bubbled exit code from provider-specific GetServerPrivateIPAddresses.sh
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

# Validate that the required target server type/name argument was provided
if [ -z "${1}" ]
then
        status "Error: Server type argument is required."
        status "Usage: $0 <server_type>"
        exit 1
fi

server_type="${1}"

# Read and validate the active cloud provider identifier
cloudhost_file="${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST"
if [ ! -f "${cloudhost_file}" ] || [ ! -r "${cloudhost_file}" ]
then
        status "Error: Cannot read active cloud host file at ${cloudhost_file}"
        exit 1
fi

CLOUDHOST="$(/bin/cat "${cloudhost_file}")"

if [ -z "${CLOUDHOST}" ]
then
        status "Error: CLOUDHOST variable is empty."
        exit 1
fi

# Locate and verify execution permissions on the provider-specific private IP resolver
script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/GetServerPrivateIPAddresses.sh"

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

# Execute the provider-specific private IP resolver with errexit paused to capture its exit code
set +e
"${script_path}" "${server_type}"
exit_code="$?"
set -e

# Bubble up any non-zero exit code returned by the provider script
if [ "${exit_code}" -ne 0 ]
then
        status "Error: GetServerPrivateIPAddresses.sh failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0

