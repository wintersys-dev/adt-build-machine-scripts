#!/bin/sh
#: Name:        list_firewalls.sh
#: Purpose:     Retrieves the unique Linode API ID of an active firewall via the Linode CLI utility.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       get_firewall_id.sh "<firewall_name>"
#:              get_firewall_id.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The firewall name/tier substring identifier to look up
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, jq, linode-cli
#:
#: Exit Codes:
#:   0          Firewall lookup completed (outputs matching ID if found, or empty if none matched)
#:   1          Missing arguments, missing context variables, or Linode CLI execution failure
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
        status "Error: Firewall configuration name argument is required."
        status "Usage: $0 <firewall_name>"
        exit 1
fi

firewall_name="${1}"

# Retrieve authentication token and active deployment identifier
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"

if [ -z "${TOKEN}" ] || [ -z "${BUILD_IDENTIFIER}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN or BUILD_IDENTIFIER)."
        exit 1
fi

# Export CLI credential token scoped strictly to the linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

set +e
response="$(/usr/local/bin/linode-cli --json firewalls list 2>&1)"
cli_status="$?"
set -e

# Immediately clear exported token from shell environment
unset LINODE_CLI_TOKEN

if [ "${cli_status}" -ne 0 ] || [ -z "${response}" ]
then
        status "Error: Linode CLI failed to retrieve firewall list (exit code: ${cli_status})."
        status "CLI Output: ${response}"
        exit 1
fi

#response="$(/bin/echo "${response}" | /usr/bin/jq -r --arg name "${firewall_name}" --arg build "-${BUILD_IDENTIFIER}" '.[] | select(.label | contains($name)) | select(.label | endswith($build)).id // empty' 2>/dev/null)"

#if [ -n "${response}" ] && [ "${response}" != "null" ]
#then
#        /bin/echo "${response}"
#fi

exit 0

