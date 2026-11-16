#!/bin/sh
#: Name:        create_firewall.sh
#: Purpose:     Provisions a new Linode native firewall using the Linode CLI utility.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       create_firewall.sh "<firewall_name>"
#:              create_firewall.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The firewall base configuration profile / role name identifier
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
#:   0          Cloud firewall created and its numeric ID returned on stdout
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
        status "Error: Firewall name argument is required."
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
response="$(/usr/local/bin/linode-cli firewalls create --json --label "${firewall_name}-${BUILD_IDENTIFIER}" --rules.inbound_policy DROP --rules.outbound_policy ACCEPT 2>&1)"
cli_status="$?"
set -e

# Immediately clear exported token from shell environment
unset LINODE_CLI_TOKEN

if [ "${cli_status}" -ne 0 ] || [ -z "${response}" ]
then
        status "Error: Linode CLI failed to create firewall (exit code: ${cli_status})."
        status "CLI Output: ${response}"
        exit 1
fi

#firewall_id="$(/bin/echo "${response}" | /usr/bin/jq -r '.[0].id // empty' 2>/dev/null)"

#if [ -z "${firewall_id}" ] || [ "${firewall_id}" = "null" ]
#then
#        status "Error: Firewall creation returned no valid ID."
#        status "CLI Output: ${response}"
#        exit 1
#fi

status "Success! Linode firewall created via CLI (ID: ${firewall_id})."
/bin/echo "${response}"

exit 0

