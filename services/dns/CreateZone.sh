#!/bin/sh
#: Name:        CreateZone.sh
#: Purpose:     Routes DNS zone creation requests to the active DNS provider script.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       CreateZone.sh <website_url>
#:              CreateZone.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The target website Fully Qualified Domain Name or URL string.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/dns/<dns_choice>/CreateZone.sh
#:   - External binaries: cat, echo, grep, cut, awk
#:
#: Exit Codes:
#:   0          Underlying DNS provider script executed cleanly
#:   1          Missing context paths, configuration faults, or missing provider script
#:   *          Bubbled exit code from provider-specific CreateZone.sh
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
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Validate that the required website URL argument was provided
if [ -z "${1}" ]
then
        status "Error: 1 argument is required."
        status "Usage: $0 <website_url>"
        exit 1
fi

website_url="${1}"

# Retrieve the active DNS provider identifier from deployment context
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

# Verify that the core software configuration file exists and is readable
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

# Extract and validate the active orchestration tool (cli or api)
orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

if [ ! -d "${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

# Locate and verify execution permissions on the provider-specific CreateZone.sh script
script_path="${BUILD_HOME}/services/dns/${DNS_CHOICE}/CreateZone.sh"

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

# Invoke the provider-specific DNS zone creation script with errexit paused
set +e
"${script_path}" "${website_url}"
exit_code="$?"
set -e

# Bubble up any non-zero exit code returned by the provider script
if [ "${exit_code}" -ne 0 ]
then
        status "Error: CreateZone.sh failed with exit code ${exit_code}"
        exit "${exit_code}"
fi

exit 0


