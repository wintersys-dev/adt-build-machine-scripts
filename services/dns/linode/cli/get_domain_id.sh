#!/bin/sh
###################################################################################
# @file        get_domain_id.sh
# @brief       Retrieves the Linode domain identifier matching a target domain URL via CLI.
# @author      Peter Winter
# @date        12/11/2026
# @version     1.1
#
# @details     This script validates the target domain URL argument, exports the required
#              infrastructure authentication tokens, queries the Linode domains catalog via
#              linode-cli, and extracts the matching numerical domain identifier cleanly.
#
# @param       $1  [Required] The target domain URL or substring to match against records.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh utility retrieving deployment context values.
#              - external dependencies: cat, echo, jq, linode-cli
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin, /usr/local/bin) to eliminate
#                executable hijack vectors.
#              - Uses jq --arg binding to prevent filter injection from untrusted domain strings.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#              - Ensures the CLI authorization token environment variable is cleared immediately post-run.
#
# @exit        0  Success: Matching domain identifier extracted cleanly.
# @exit        *  Failure: Missing arguments, layout faults, missing context variables,
#                 no matching domain found, or bubbling exit codes from linode-cli.
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
set -e

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Force status helper messages strictly onto stderr to preserve clean data streaming on stdout
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

if [ -z "${1}" ]
then
        status "Error: Target domain URL argument is required."
        status "Usage: $0 <domain_url>"
        exit 1
fi

domain_url="${1}"

TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

export LINODE_CLI_TOKEN="${TOKEN}"

set +e
api_domain_json="$(/usr/local/bin/linode-cli --no-defaults --json domains list)"
exit_code="$?"
set -e

# Unset token instantly to maintain high security-isolation states
unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ]
then
        status "Error: linode-cli domains list failed with exit code ${exit_code}."
        exit "${exit_code}"
fi

# linode-cli --json returns a top-level array rather than wrapping results in .data[]
set +e
DOMAIN_ID=$(/bin/echo "${api_domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '.[] | select(.domain | contains($dom)) | .id // empty' 2>/dev/null)
jq_exit_code="$?"
set -e

if [ "${jq_exit_code}" -ne 0 ]
then
        status "Error: Failed to parse domain JSON payload with jq (exit code ${jq_exit_code})."
        exit 1
fi

if [ -z "${DOMAIN_ID}" ]
then
        status "Error: No matching domain ID found for domain '${domain_url}'."
        exit 2
fi

status "Success: Extracted domain ID ${DOMAIN_ID} for domain '${domain_url}'."
/bin/echo "${DOMAIN_ID}"
exit 0
