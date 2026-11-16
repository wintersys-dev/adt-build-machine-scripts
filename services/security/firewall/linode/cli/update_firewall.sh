#!/bin/sh
#: Name:        update_firewall.sh
#: Purpose:     Applies a custom inbound network ruleset payload to a specified Linode firewall via Linode CLI.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       update_firewall.sh "<firewall_id>" "<ruleset_json>"
#:              update_firewall.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique numeric ID of the target Linode firewall to update
#:   $2         [Required] The JSON array string representing inbound firewall rules
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
#:   0          Firewall ruleset updated successfully via Linode CLI
#:   1          Missing arguments, invalid JSON ruleset, missing context variables, or CLI execution failure
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
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Both firewall ID and ruleset arguments are required."
        status "Usage: $0 <firewall_id> <ruleset_json>"
        exit 1
fi

firewall_id="${1}"
ruleset="${2}"

# Validate and compact the inbound firewall rules JSON array via jq
validated_ruleset="$(/bin/echo "${ruleset}" | /usr/bin/jq -c '.' 2>/dev/null || true)"

if [ -z "${validated_ruleset}" ]
then
        status "Error: Invalid JSON ruleset supplied for firewall update."
        exit 1
fi

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
response="$(/usr/local/bin/linode-cli firewalls rules-update --inbound "${validated_ruleset}" "${firewall_id}" 2>&1)"
cli_status="$?"
set -e

# Immediately clear exported token from shell environment
unset LINODE_CLI_TOKEN

if [ "${cli_status}" -ne 0 ]
then
        status "Error: Linode CLI failed to update rules for firewall ${firewall_id} (exit code: ${cli_status})."
        status "CLI Output: ${response}"
        exit 1
fi

status "Success! Linode firewall ${firewall_id} rules updated via CLI."

exit 0

