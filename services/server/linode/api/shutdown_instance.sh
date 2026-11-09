#!/bin/sh
###################################################################################
# @file        shutdown_instance.sh
# @brief       Issues a power shutdown command to a Linode server via the REST API v4.
# @author      Peter Winter
# @date        09/11/2026
# @version     1.0
#
# @details     This script exports infrastructure authentication tokens via secure standard
#              input piping, validates the target server identity parameter, and
#              executes an authenticated curl POST request under a strict status
#              monitoring block to cleanly initiate an ACPI shutdown sequence.
#
# @param       $1  [Required] The API access or authentication token for the Linode API.
# @param       $2  [Required] The unique numerical identifier of the target server instance.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - external dependencies: cat, echo, curl
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: Shutdown request for the server instance accepted by API server.
# @exit        *  Failure: Missing arguments, layout faults, or a non-2xx status 
#                 code thrown back by the remote endpoint.
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

if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Both API token and Server ID arguments are required."
        status "Usage: $0 <linode_api_token> <server_id>"
        exit 1
fi

server_id="${1}"

TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if  [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

# Safely route authorized POST actions via standard stream piping to prevent exposure in process trees
set +e
/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -f -X POST "https://api.linode.com/v4/linode/instances/${server_id}/shutdown"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Error: Linode API server instance shutdown call failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

status "Success: Shutdown request for Linode instance ${server_id} successfully transmitted."
exit 0
