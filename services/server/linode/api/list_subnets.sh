#!/bin/sh
###################################################################################
# @file        list_subnets.sh
# @brief       Lists all subnets associated with a specific Linode VPC network via API.
# @author      Peter Winter
# @date        09/11/2026
# @version     1.0
#
# @details     This script exports infrastructure authentication tokens via secure standard
#              input piping, validates the target VPC network identifier parameter, and 
#              executes an authenticated curl GET request under a strict status 
#              monitoring block to extract the allocated subnets array in JSON format.
#
# @param       $1  [Required] The API access or authentication token for the Linode API.
# @param       $2  [Required] The unique numerical identifier of the target VPC network.
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
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#
# @exit        0  Success: VPC subnets array queried and printed cleanly.
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

# Force status helper messages strictly onto stderr to preserve clean data streaming on stdout
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

if [ -z "${1}" ] 
then
        status "Error:  VPC ID argument is required."
        status "Usage: $0 <vpc_id>"
        exit 1
fi

vpc_id="${1}"

TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if  [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

set +e
# Safely route authorized actions via stream piping to prevent exposure in process trees
RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s "https://api.linode.com/v4/vpcs/${vpc_id}/subnets" -w "\nHTTP_STATUS:%{http_code}")
set -e
# Extract the HTTP status code (e.g., 200, 404, 401) using strict POSIX filtering
HTTP_CODE=$(/bin/echo "$RESPONSE" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)

# Extract the raw response body by dropping the status delimiter line
RESPONSE_BODY=$(/bin/echo "$RESPONSE" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate the API response code using strict POSIX structural matching
case "${HTTP_CODE}" in
    200)
        # Safely parse out the raw array from the verified response block and output to stdout
        /bin/echo "${RESPONSE_BODY}" | /usr/bin/jq '.data'
        exit 0
        ;;
    400)
        status "Error 400: Bad Request. Check syntax or target endpoint layout parameters."
        status "API Detail: ${RESPONSE_BODY}"
        exit 400
        ;;
    401)
        status "Error 401: Unauthorized. Your authentication TOKEN is invalid or has expired."
        exit 401
        ;;
    403)
        status "Error 403: Forbidden. Token lacks permissions to look up VPC subnets."
        exit 403
        ;;
    404)
        status "Error 404: Not Found. The requested VPC network layout ${vpc_id} does not exist."
        exit 404
        ;;
    429)
        status "Error 429: Rate Limit Exceeded. Back off request frequency."
        exit 429
        ;;
    5*)
        status "Error ${HTTP_CODE}: Linode Gateway or Remote Server Exception."
        exit 500
        ;;
    *)
        status "Error ${HTTP_CODE}: Remote endpoint refused connection or threw an unexpected code."
        status "API Detail: ${RESPONSE_BODY}"
        exit 1
        ;;
esac


exit 0
