#!/bin/sh
#: Name:        update_dbaas_firewall.sh
#: Purpose:     Updates the network firewall allow list for a managed Linode PostgreSQL DBaaS cluster via CLI.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       update_dbaas_firewall.sh <database_id> <allow_list>
#:              update_dbaas_firewall.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique Linode platform identifier ID of the active database instance.
#:   $2         [Required] Comma-separated IP/CIDR allow list string (e.g. "10.0.0.0/24" or "0.0.0.0/0").
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
#:   0          Target database network access control rules modified cleanly via CLI
#:   1          Missing context paths, parameter validation error, or CLI failure
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
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Validate that both database ID and allow list arguments were provided
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Database ID and allow_list parameters are required."
        status "Usage: $0 <database_id> <allow_list>"
        exit 1
fi

database_id="${1}"
allow_list="${2}"

# Retrieve the cloud provider authentication token from the active deployment context
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Export authentication token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Verify that the linode-cli binary is installed and executable
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Execute the PostgreSQL firewall allow list update via linode-cli with errexit paused
set +e
/usr/local/bin/linode-cli databases postgresql-update "${database_id}" --allow_list "${allow_list}" --no-defaults
exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI call finishes
unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ]
then
        status "Database ${database_id} firewall allow list failed to update via Linode CLI."
        exit 1
fi

status "Database ${database_id} firewall access network settings successfully modified via CLI."
exit 0

