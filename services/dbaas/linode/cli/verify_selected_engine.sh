#!/bin/sh
#: Name:        verify_selected_engine.sh
#: Purpose:     Validates chosen database engine compatibility using the Linode CLI.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.1
#:
#: Usage:       verify_selected_engine.sh
#:              verify_selected_engine.sh [-h|--help]
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
#:   0          Target database engine successfully verified against cloud catalog
#:   1          Missing configuration contexts, CLI runtime errors, or unsupported engine
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

if [ -z "${DATABASE_DBaaS_INSTALLATION_TYPE}" ] || [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (DATABASE_DBaaS_INSTALLATION_TYPE or TOKEN)."
        exit 1
fi

# Extract the target engine identifier string from the 3rd colon-delimited field
engine="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $3}')"

if [ -z "${engine}" ]
then
        status "Error: Missing database engine identifier in DATABASE_DBaaS_INSTALLATION_TYPE."
        exit 1
fi

# Verify that the linode-cli binary is installed and executable
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        exit 1
fi

# Export authentication token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Query available managed database engines via linode-cli with errexit paused
set +e
cli_output="$(/usr/local/bin/linode-cli databases engines --no-defaults --json 2>/dev/null)"
exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI call finishes
unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ] || [ -z "${cli_output}" ]
then
        status "Failed to obtain list of available engines via Linode CLI."
        exit 1
fi

# Extract all supported engine IDs from the returned catalog payload
available_engines="$(/bin/echo "${cli_output}" | /usr/bin/jq -r '.[].id // empty')"

if [ -z "${available_engines}" ]
then
        status "Failed to parse available engines from the cloud management catalog metadata via CLI."
        exit 1
fi

# Verify that the configured engine exists as an exact fixed-string word match in the available list
set +e
/bin/echo "${available_engines}" | /bin/grep -F -q -w "${engine}"
match_code="$?"
set -e

if [ "${match_code}" -ne 0 ]
then
        status "The database engine you have selected (${engine}) is not available. Please correct and re-deploy."
        exit 1
fi

status "Database engine '${engine}' successfully verified via CLI against cloud catalog matrix... OK to proceed."
exit 0




