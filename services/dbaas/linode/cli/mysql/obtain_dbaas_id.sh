#!/bin/sh
#: Name:        obtain_dbaas_id.sh
#: Purpose:     Resolves the Linode platform instance ID for a MySQL DBaaS cluster label via CLI.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       obtain_dbaas_id.sh
#:              obtain_dbaas_id.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads DATABASE_DBaaS_INSTALLATION_TYPE and TOKEN via GetVariableValue.sh.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, awk, linode-cli, jq
#:
#: Exit Codes:
#:   0          Target cluster unique platform ID successfully resolved and printed
#:   1          Missing configuration contexts, CLI runtime errors, or label mismatch
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

# Retrieve DBaaS installation profile and authentication token from active context
DATABASE_DBaaS_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_DBaaS_INSTALLATION_TYPE)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Extract the target database cluster label from the 7th colon-delimited field
label="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $7}')"
# Export authentication token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Verify that the linode-cli binary is installed and executable
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Query the Linode MySQL DBaaS instance catalog via CLI with errexit paused
set +e
cli_output="$(/usr/local/bin/linode-cli databases mysql-list --no-defaults --json 2>/dev/null)"
exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI call finishes
unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ] || [ -z "${cli_output}" ]
then
        status "Failed to query CLI cluster management catalog or tool runtime error occurred."
        exit 1
fi

# Filter the returned cluster array safely via jq for the matching cluster label
database_id="$(/bin/echo "${cli_output}" | /usr/bin/jq -r --arg lbl "${label}" '.[] | select(.label | contains($lbl)) | .id // empty')"

if [ -z "${database_id}" ]
then
        status "Database ID not available for label '${label}' (Instance not found or structural metadata fault)."
        exit 1
fi

/bin/echo "${database_id}"
exit 0


