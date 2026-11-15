#!/bin/sh
#: Name:        GetOperatingSystemVersion.sh
#: Purpose:     Orchestrates cloud-provider specific operating system version resolution.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       GetOperatingSystemVersion.sh
#:              GetOperatingSystemVersion.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads BUILDOS and BUILDOS_VERSION dynamically via GetVariableValue.sh.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Operating system distribution translation slug resolved cleanly
#:   1          Missing configuration files, unreadable state, or missing provider script
#:   *          Bubbled exit code from provider-specific GetOperatingSystemVersion.sh
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

# Fetch the target operating system name and release version from active configuration
BUILDOS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILDOS)"
BUILDOS_VERSION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILDOS_VERSION)"

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

# Verify that the core software configuration registry is present and readable
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

# Locate and verify execution permissions on the provider-specific OS version resolver
script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/GetOperatingSystemVersion.sh"

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

# Execute the provider-specific OS resolver with errexit paused to capture its exit code
set +e
"${script_path}" "${BUILDOS}" "${BUILDOS_VERSION}"
exit_code="$?"
set -e

# Bubble up any non-zero exit code returned by the provider script
if [ "${exit_code}" -ne 0 ]
then
        status "Error: GetOperatingSystemVersion.sh failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0


