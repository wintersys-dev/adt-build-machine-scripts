#!/bin/sh
#: Name:        get_domains.sh
#: Purpose:     Retrieves all configured DNS domains from the Linode account via linode-cli.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       get_domains.sh
#:              get_domains.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads TOKEN via GetVariableValue.sh.
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
#:   0          Account DNS domain payload retrieved cleanly
#:   1          Layout faults or missing context variables
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

# Route status log entries strictly to stderr so stdout remains clean JSON for callers
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Retrieve the cloud provider authentication token from the active deployment context
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

# Export the API token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Execute the DNS domains list query via linode-cli with errexit paused
set +e
/usr/local/bin/linode-cli --no-defaults --json domains list
exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI call finishes
unset LINODE_CLI_TOKEN

# Bubble up any non-zero exit code thrown by linode-cli
if [ "${exit_code}" -ne 0 ]
then
        status "Error: linode-cli domains list failed with exit code ${exit_code}."
        exit "${exit_code}"
fi

exit 0

