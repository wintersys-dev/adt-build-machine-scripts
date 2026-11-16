#!/bin/sh
#: Name:        ConfigureNativeFirewall.sh
#: Purpose:     Configures the native cloud firewall to restrict infrastructure access by IP.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       ConfigureNativeFirewall.sh "<firewall_name>"
#:              ConfigureNativeFirewall.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The firewall rule deployment name or configuration profile identifier
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Native firewall policy deployed successfully or bypassed when inactive
#:   1          Missing arguments, missing config/scripts, or downstream execution failure
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

# Validate required positional arguments
if [ -z "${1}" ]
then
        status "Error: 1 argument is required."
        status "Usage: $0 <firewall_name>"
        exit 1
fi

firewall_name="${1}"

# Retrieve active firewall policy and cloud host identifiers
ACTIVE_FIREWALLS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" ACTIVE_FIREWALLS)"
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"

if [ -z "${ACTIVE_FIREWALLS}" ] || [ -z "${CLOUDHOST}" ]
then
        status "Error: Failed to fetch required context variables (ACTIVE_FIREWALLS or CLOUDHOST)."
        exit 1
fi

# Execute vendor-specific firewall configuration when native firewalls are active
if [ "${ACTIVE_FIREWALLS}" = "2" ] || [ "${ACTIVE_FIREWALLS}" = "3" ]
then
        software_file="${BUILD_HOME}/configuration/software.dat"

        if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
        then
                status "Error: Cannot read software configuration file at ${software_file}"
                exit 1
        fi

        script_path="${BUILD_HOME}/services/security/firewall/${CLOUDHOST}/ConfigureNativeFirewall.sh"

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

        set +e
        output="$("${script_path}" "${firewall_name}")"
        exit_code="$?"
        set -e

        if [ "${exit_code}" -ne 0 ]
        then
                status "Error: ${script_path} failed with exit code ${exit_code}."
                exit 1
        else
                status "Success! Native firewall configured for ${firewall_name}."
                /bin/echo "${output}"
        fi
fi

exit 0




