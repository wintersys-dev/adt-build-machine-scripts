#!/bin/sh
#: Name:        reset_firewall.sh
#: Purpose:     Resets a Linode native firewall's rules to empty arrays with default policies via REST API v4.
#: Author:      Peter Winter
#: Date:        16/11/2026
#: Version:     1.0
#:
#: Usage:       reset_firewall.sh "<firewall_id>"
#:              reset_firewall.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique numeric ID of the target Linode firewall to reset
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
#:   0          Firewall rules matrix flushed and default policies applied
#:   1          Missing arguments, missing context variables, encoding failure, or non-2xx API status
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
        status "Error: Firewall system identifier argument is required."
        status "Usage: $0 <firewall_id>"
        exit 1
fi

firewall_id="${1}"

# Retrieve authentication token
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variable (TOKEN)."
        exit 1
fi

# Construct the reset firewall rules JSON payload safely via jq
rules_payload="$(/usr/bin/jq -n -c '{ inbound: [], outbound: [], inbound_policy: "DROP", outbound_policy: "ACCEPT" }' 2>/dev/null)"

if [ -z "${rules_payload}" ]
then
        status "Error: Failed to construct valid firewall rules JSON."
        exit 1
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/networking/firewalls/${firewall_id}/rules"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Submit the firewall rules PUT request with token passed securely via stdin
set +e
RESPONSE=$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s -X PUT "${endpoint}" -H "Content-Type: application/json" -d "${rules_payload}" -w "\nHTTP_STATUS:%{http_code}")
set -e

# Separate the HTTP status code and JSON response body
HTTP_CODE=$(/bin/echo "${RESPONSE}" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)
RESPONSE_BODY=$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate HTTP status code and handle API errors explicitly
case "${HTTP_CODE}" in
        200|201)
                status "Success! Linode firewall ${firewall_id} rules reset."
                ;;
        400)
                status "Error 400: Bad Request. Check your payload syntax."
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
        404)
                status "Error 404: Not Found. Firewall ID ${firewall_id} does not exist."
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

