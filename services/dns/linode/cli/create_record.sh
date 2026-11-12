#!/bin/sh
###################################################################################
# @file        create_record.sh
# @brief       Creates a new DNS record under a specific Linode domain via CLI.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.1
#
# @details     This script exports the required infrastructure authentication tokens,
#              validates the presence of target domain identifiers and record creation
#              payloads, and executes the provider CLI tool with strict status capture
#              routines to create a DNS record under the target domain.
#
# @param       $1  [Required] The unique numerical identifier of the target DNS domain.
# @param       $2  [Required] A valid JSON payload containing DNS record specification details.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - external dependencies: cat, echo, linode-cli
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/local/bin) to eliminate executable hijack vectors.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#              - Ensures the CLI authorization token environment variable is cleared immediately post-run.
#
# @exit        0  Success: Target DNS domain record created cleanly.
# @exit        *  Failure: Missing arguments, missing framework layouts, or bubbling
#                 exit codes generated directly by the underlying cloud execution client.
##################################################################################
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
#set -x
set -e

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Domain ID and JSON payload arguments are required."
        status "Usage: $0 <domain_id> <json_payload>"
        exit 1
fi

domain_id="${1}"
json_payload="${2}"

# Reset positional parameters ($@) to build the dynamic flag list
set --

# Convert {"type":"A","name":"www","target":"1.2.3.4"} into --type A --name www --target 1.2.3.4
while IFS= read -r line
do
        [ -n "${line}" ] && set -- "$@" "${line}"
done <<EOF
$(/bin/echo "${json_payload}" | /usr/bin/jq -r 'to_entries[] | select(.value != null and .value != "") | "--\(.key)", (.value | tostring)')
EOF

TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

export LINODE_CLI_TOKEN="${TOKEN}"

set +e
/usr/local/bin/linode-cli --no-defaults --json domains records-create "${domain_id}" "$@"
exit_code="$?"
set -e

# Unset token instantly to maintain high security-isolation states
unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ]
then
        status "Error: linode-cli domains records-create failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

status "Success: Linode DNS record created cleanly."
exit 0
