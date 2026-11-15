#!/bin/sh
#: Name:        GetProxyDNSIPs.sh
#: Purpose:     Routes proxy server DNS IP retrieval requests to the active DNS provider script.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       GetProxyDNSIPs.sh <auth>
#:              GetProxyDNSIPs.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Authority flag validation parameter ("yes" / "no").
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/services/dns/<dns_choice>/GetProxyDNSIPs.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Underlying DNS provider script executed cleanly or was skipped
#:   1          Missing context paths, non-executable provider script, or tool failure
#:   *          Bubbled exit code from provider-specific GetProxyDNSIPs.sh
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
set -x
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

# Validate that the required authority flag argument was provided
if [ -z "${1}" ]
then
        status "Error: 1 argument is required."
        status "Usage: $0 <auth>"
        exit 1
fi

auth="${1}"

# Determine the target DNS provider (switching to AUTH_DNS_CHOICE when auth="yes")
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

if [ "${auth}" = "yes" ]
then
        DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" AUTH_DNS_CHOICE)"
fi

# Locate the optional provider-specific GetProxyDNSIPs.sh script
script_path="${BUILD_HOME}/services/dns/${DNS_CHOICE}/GetProxyDNSIPs.sh"

# Execute the provider script only if it exists for the selected DNS provider
if [ -f "${script_path}" ]
then
        if [ ! -x "${script_path}" ]
        then
                status "Error: Script at ${script_path} is not executable."
                exit 1
        fi

        # Invoke the provider-specific proxy DNS IP lookup script with errexit paused
        set +e
        "${script_path}"
        exit_code="$?"
        set -e

        # Bubble up any non-zero exit code returned by the provider script
        if [ "${exit_code}" -ne 0 ]
        then
                status "Error: GetProxyDNSIPs.sh failed with exit code ${exit_code}"
                exit "${exit_code}"
        fi
fi

exit 0


