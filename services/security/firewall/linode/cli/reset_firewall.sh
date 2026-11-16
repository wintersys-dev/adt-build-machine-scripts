#!/bin/sh
#: Name:        reset_firewall.sh
#: Purpose:     Resets a Linode native firewall's rule matrix using the Linode CLI utility.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       reset_firewall.sh "<firewall_id>"
#:              reset_firewall.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique numeric ID of the target Linode firewall to reset
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, linode-cli
#:
#: Exit Codes:
#:   0          Firewall rules matrix flushed and default policies applied
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
        status "Error: Firewall system identifier argument is required."
        status "Usage: $0 <firewall_id>"
        exit 1
fi

firewall_id="${1}"

# Retrieve authentication token
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variable (TOKEN)."
        exit 1
fi

# Export CLI credential token scoped strictly to the linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

set +e
response="$(/usr/local/bin/linode-cli firewalls rules-update --inbound '[]' --outbound '[]' --inbound_policy DROP --outbound_policy ACCEPT "${firewall_id}" 2>&1)"
cli_status="$?"
set -e

# Immediately clear exported token from shell environment
unset LINODE_CLI_TOKEN

if [ "${cli_status}" -ne 0 ]
then
        status "Error: Linode CLI failed to reset firewall ${firewall_id} (exit code: ${cli_status})."
        status "CLI Output: ${response}"
        exit 1
fi

status "Success! Linode firewall ${firewall_id} rules reset via CLI."

exit 0

