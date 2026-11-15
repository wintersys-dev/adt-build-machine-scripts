#!/bin/sh
#: Name:        delete_instance.sh
#: Purpose:     Decommissions and deletes an existing Linode server instance via linode-cli.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       delete_instance.sh <server_id>
#:              delete_instance.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique numerical or textual identifier of the target server.
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
#:   0          Target server instance deleted cleanly
#:   1          Missing arguments, layout faults, or context variable errors
#:   *          Bubbled exit code from linode-cli
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

# Route status log entries strictly to stderr so stdout remains clean for callers
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Validate that the required target server ID argument was provided
if [ -z "${1}" ]
then
        status "Error: Server ID argument is required."
        status "Usage: $0 <server_id>"
        exit 1
fi

server_id="${1}"

# Retrieve the cloud provider authentication token from the active deployment context
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

# Export the API token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Execute the instance deletion call with errexit paused to capture the CLI exit code
set +e
/usr/local/bin/linode-cli --no-defaults --json linodes delete "${server_id}"
exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI call finishes
unset LINODE_CLI_TOKEN

# Bubble up any non-zero exit code thrown by linode-cli
if [ "${exit_code}" -ne 0 ]
then
        status "Error: linode-cli linodes delete failed with exit code ${exit_code}."
        exit "${exit_code}"
fi

status "Success: Linode instance ${server_id} successfully decommissioned."
exit 0


