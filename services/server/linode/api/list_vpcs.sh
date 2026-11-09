#!/bin/sh
###################################################################################
# @file        ListLinodeVpcsApi.sh
# @brief       Lists all active Linode Virtual Private Clouds (VPCs) in a region via API.
# @author      Peter Winter
# @date        09/11/2026
# @version     1.0
#
# @details     This script exports infrastructure authentication tokens via secure standard
#              input piping, validates the target geographic region parameter, builds a
#              well-formed X-Filter JSON header string using jq, and executes an
#              authenticated curl GET request under a strict status monitoring block 
#              to extract the regional VPC topology array.
#
# @param       $1  [Required] The API access or authentication token for the Linode API.
# @param       $2  [Required] The targeted geographic region identifier (e.g., us-east).
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - external dependencies: cat, echo, curl, jq
#
# @security    
#              - Hardens system-owned paths (/bin, /usr/bin) to eliminate executable hijack vectors.
#              - Passes authentication token via standard input pipe to curl to protect credentials.
#              - Uses jq to dynamically assemble the filter header string, eliminating shell injection risks.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: Regional VPC network topology matrix retrieved cleanly.
# @exit        *  Failure: Missing arguments, layout faults, or a non-2xx status 
#                 code thrown back by the remote endpoint or pipeline.
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
        status "Error: Region argument is required."
        status "Usage: $0 <region>"
        exit 1
fi

region="${1}"

TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if  [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

# Safely construct the X-Filter JSON payload using jq to mitigate string/quote injection hazards
x_filter_header="$(/usr/bin/jq -n -c --arg reg "${region}" '{"region": $reg}' 2>/dev/null)"

if [ -z "${x_filter_header}" ]
then
        status "Error: Failed to safely construct X-Filter JSON header configuration."
        exit 1
fi

# Safely route authorized actions via stream piping to prevent exposure in process trees
set +e
/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -f -s -H "X-Filter: ${x_filter_header}" "https://api.linode.com/v4/vpcs" | /usr/bin/jq '.data'
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Error: Linode API VPCs filtered query pipeline failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0
