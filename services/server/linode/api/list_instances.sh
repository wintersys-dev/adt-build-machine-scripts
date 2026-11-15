#!/bin/sh
#: Name:        list_instances.sh
#: Purpose:     Lists all active Linode compute instances within a specified region via API.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       list_instances.sh <region>
#:              list_instances.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The targeted geographic region identifier (e.g., eu-west, us-east).
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, sed, curl, jq
#:
#: Exit Codes:
#:   0          Regional instance array queried and printed cleanly
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

# Validate that the required geographic region argument was provided
if [ -z "${1}" ]
then
        status "Error: Region argument is required."
        status "Usage: $0 <region>"
        exit 1
fi

region="${1}"

# Retrieve the cloud provider authentication token from the active deployment context
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

# Construct the X-Filter JSON header safely via jq to avoid quote injection
x_filter_header="$(/usr/bin/jq -n -c --arg reg "${region}" '{"region": $reg}' 2>/dev/null)"

if [ -z "${x_filter_header}" ]
then
        status "Error: Failed to safely construct X-Filter JSON header configuration."
        exit 1
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/linode/instances"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Submit the regional instance lookup GET request with token passed securely via stdin
set +e
RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -H "X-Filter: ${x_filter_header}" "${endpoint}" -w "\nHTTP_STATUS:%{http_code}")
set -e

# Separate the HTTP status code and JSON response body
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate HTTP status code and output the extracted .data array on success
case "${HTTP_CODE}" in
        200)
                /bin/echo "${RESPONSE_BODY}" | /usr/bin/jq '.data'
                exit 0
                ;;
        400)
                status "Error 400: Bad Request. Check syntax or filter parameter mapping."
                status "API Detail: ${RESPONSE_BODY}"
                exit 400
                ;;
        401)
                status "Error 401: Unauthorized. Your authentication TOKEN is invalid or has expired."
                exit 401
                ;;
        403)
                status "Error 403: Forbidden. Token lacks permissions to list regional compute units."
                exit 403
                ;;
        404)
                status "Error 404: Not Found. The requested API endpoint could not be found."
                status "API Detail: ${RESPONSE_BODY}"
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

