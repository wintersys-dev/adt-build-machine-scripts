#!/bin/sh
#: Name:        list_firewalls.sh
#: Purpose:     Retrieves the unique Linode API ID of an active firewall by name and build identifier.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       list_firewalls.sh "<firewall_name>"
#:              list_firewalls.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The firewall name/tier substring identifier to look up
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, sed, jq, curl
#:
#: Exit Codes:
#:   0          Firewall lookup completed (outputs matching ID if found, or empty if none matched)
#:   1          Missing arguments, missing context variables, or non-2xx API status
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
#set -x
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

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Validate required positional arguments
if [ -z "${1}" ]
then
        status "Error: Firewall configuration name argument is required."
        status "Usage: $0 <firewall_name>"
        exit 1
fi

firewall_name="${1}"

# Retrieve authentication token and active deployment identifier
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"

if [ -z "${TOKEN}" ] || [ -z "${BUILD_IDENTIFIER}" ]
then
        status "Error: Failed to fetch required context variables (TOKEN or BUILD_IDENTIFIER)."
        exit 1
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/networking/firewalls"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Submit the firewall list GET request with token passed securely via stdin
set +e
RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -X GET "${endpoint}" -w "\nHTTP_STATUS:%{http_code}")
set -e

# Separate the HTTP status code and JSON response body
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate HTTP status code and handle API errors explicitly
case "${HTTP_CODE}" in
        200|201)
                /bin/echo "${RESPONSE_BODY}" | /usr/bin/jq -r '.data'

                #firewall_id="$/bin/echo "${RESPONSE_BODY}" | /usr/bin/jq -r --arg name "${firewall_name}" --arg build "-${BUILD_IDENTIFIER}" '.data[] | select(.label | contains($name)) | select(.label | endswith($build)).id' 2>/dev/null)"

                #if [ -n "${firewall_id}" ] && [ "${firewall_id}" != "null" ]
                #then
                #        /bin/echo "${firewall_id}"
                #fi
                ;;
        400)
                status "Error 400: Bad Request. Check your request parameters."
                status "API Response: ${RESPONSE_BODY}"
                exit 1
                ;;
        401)
                status "Error 401: Unauthorized. Check your TOKEN."
                exit 1
                ;;
        403)
                status "Error 403: Forbidden. Missing permissions."
                exit 1
                ;;
        429)
                status "Error 429: Rate Limit Exceeded."
                exit 1
                ;;
        5*)
                status "Error ${HTTP_CODE}: Linode Server Error."
                exit 1
                ;;
        *)
                status "Error ${HTTP_CODE}: Unexpected response."
                status "API Response: ${RESPONSE_BODY}"
                exit 1
                ;;
esac

exit 0
