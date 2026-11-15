#!/bin/sh
#: Name:        create_vpc.sh
#: Purpose:     Provisions a Linode Virtual Private Cloud (VPC) directly via the REST API v4.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       create_vpc.sh <vpc_json_payload>
#:              create_vpc.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] A valid JSON payload string containing VPC specification details.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, sed, curl
#:
#: Exit Codes:
#:   0          VPC network configuration accepted by the API server
#:   *          Missing arguments, layout faults, or non-2xx HTTP status code
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
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries strictly to stderr so stdout remains clean JSON for callers
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Validate that the required VPC JSON payload argument was provided
if [ -z "${1}" ]
then
        status "Error: VPC configuration payload argument is required."
        status "Usage: $0 <vpc_json_payload>"
        exit 1
fi

vpc_payload="${1}"

# Retrieve the cloud provider authentication token from the active deployment context
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/vpcs"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Submit the VPC creation POST request with token passed securely via stdin
set +e
RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -X POST "${endpoint}" -H "Content-Type: application/json" -d "${vpc_payload}" -w "\nHTTP_STATUS:%{http_code}")
set -e

# Separate the HTTP status code and JSON response body
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate HTTP status code and stream JSON body back to stdout on success
case "${HTTP_CODE}" in
        200|201)
                status "Success: VPC network configuration payload transmitted cleanly to endpoints."
                /bin/echo "${RESPONSE_BODY}"
                exit 0
                ;;
        400)
                status "Error 400: Bad Request. Check your VPC JSON payload formatting."
                status "API Detail: ${RESPONSE_BODY}"
                exit 400
                ;;
        401)
                status "Error 401: Unauthorized. Your authentication TOKEN is invalid or has expired."
                exit 401
                ;;
        403)
                status "Error 403: Forbidden. Token lacks permissions to create VPC resources."
                exit 403
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
