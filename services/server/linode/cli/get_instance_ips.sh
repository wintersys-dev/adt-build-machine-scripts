#!/bin/sh
###################################################################################
# @file        get_instance_ips.sh
# @brief       Retrieves and filters IP addressing allocation metadata for a Linode server.
# @author      Peter Winter
# @date        09/11/2026
# @version     1.0
#
# @details     This script exports the required infrastructure authentication tokens,
#              validates the target server identity parameter, invokes the provider
#              CLI client under a strict status monitoring block, and pipes the output
#              through a JSON processor to unpack individual IP profiles.
#
# @param       $1  [Required] The API access or authentication token for the Linode CLI.
# @param       $2  [Required] The unique numerical or textual identifier of the target server.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - external dependencies: cat, echo, linode-cli, jq
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin, /usr/local/bin) to eliminate executable hijack vectors.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#              - Restricts authorization lifetime by unsetting credentials immediately post-execution.
#
# @exit        0  Success: Target server IP allocation configuration fetched cleanly.
# @exit        *  Failure: Missing arguments, unreadable base paths, or cascading 
#                 exit failures bubbling up from the provider API client or pipeline.
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

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

if [ -z "${1}" ] 
then
        status "Error: Server ID argument is required."
        status "Usage: $0  <server_id>"
        exit 1
fi

server_id="${1}"

TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if  [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

export LINODE_CLI_TOKEN="${TOKEN}"

set +e
/usr/local/bin/linode-cli --json linodes ips-list "${server_id}" | /usr/bin/jq '.[]'
exit_code="$?"
set -e

# Unset token instantly to maintain high security-isolation states
unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ]
then
        status "Error: linode-cli linodes ips-list pipeline failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0

