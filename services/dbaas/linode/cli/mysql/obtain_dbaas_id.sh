#!/bin/sh
###################################################################################
# @file        obtain_dbaas_id.sh
# @brief       Resolves the platform instance ID for a given DBaaS cluster label via CLI.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script queries the cloud provider managed database instances catalog
#              using the Linode CLI, filters matching nodes securely via string contains
#              checks inside jq, validates the payload, and outputs the cluster ID.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, linode-cli, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Masks API interactions securely via short-lived environment variable hooks.
#              - Protects against JSON payload tracking injection vulnerabilities.
#
# @exit        0  Success: Target cluster unique platform ID successfully resolved and printed.
# @exit        1  Failure: Missing configuration contexts, CLI runtime errors, or label mismatch.
###################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
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
set -e

# Resolve BUILD_HOME baseline layout securely
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Framework deployment variables extraction using secure subshells
DATABASE_DBaaS_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_DBaaS_INSTALLATION_TYPE)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Extract specific cluster identifier string cleanly
label="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $7}')"

# Export authentication credentials safely within bounded local environment execution tracks
export LINODE_CLI_TOKEN="${TOKEN}"

# Validate CLI execution dependencies before invoking structural deployment steps
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Execute catalog resolution securely with manual intercept hooks to catch runtime exceptions
set +e
cli_output="$("/usr/local/bin/linode-cli" databases mysql-list --no-defaults --json 2>/dev/null)"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${cli_output}" ]
then
        status "Failed to query CLI cluster management catalog or tool runtime error occurred."
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Parse matching entity profiles defensively using parameters isolation tracking
database_id="$(/bin/echo "${cli_output}" | /usr/bin/jq -r --arg lbl "${label}" '.[] | select(.label | contains($lbl)) | .id // empty')"

if [ -z "${database_id}" ]
then
        status "Database ID not available for label '${label}' (Instance not found or structural metadata fault)."
        unset LINODE_CLI_TOKEN
        exit 1
fi

unset LINODE_CLI_TOKEN

/bin/echo "${database_id}"
exit 0

