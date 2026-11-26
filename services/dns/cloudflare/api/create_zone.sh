#!/bin/sh
#: Name:        create_zone.sh
#: Purpose:     Provisions a new authoritative DNS zone on Cloudflare via REST API.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       create_zone.sh <zone_name>
#:              create_zone.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The apex root domain zone name (e.g. "example.com").
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, tr, grep, cut, sed, awk, curl
#:
#: Exit Codes:
#:   0          Cloudflare DNS zone created and JSON response emitted cleanly
#:   1          Missing arguments, layout faults, network failure, or HTTP error
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
set -x
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
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries strictly to stderr so stdout remains clean JSON for callers
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null >&2
}

# Validate that the required target zone_name argument was provided
if [ -z "${1}" ]
then
        status "Error: zone_name parameter is required."
        status "Usage: $0 <zone_name>"
        exit 1
fi

# Strip any accidental whitespace/newlines from zone_name
zone_name="$(/bin/echo "${1}" | /usr/bin/tr -d '[:space:]')"

if [ -z "${zone_name}" ]
then
        status "Error: zone_name is empty after whitespace removal."
        exit 1
fi

# Retrieve Cloudflare authentication credentials from active deployment context
DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"
DNS_SECURITY_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_SECURITY_KEY)"
# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="cloudflare.com"
api_path="client/v4/zones"
endpoint="https://${api_sub}.${api_domain}/${api_path}"


# Submit the zone creation POST request using Bearer token or legacy Global API Key
set +e
if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        account_id="${DNS_SECURITY_KEY%:::*}"
        api_token="${DNS_SECURITY_KEY#*:::}"
        json_payload='{"name":"'${zone_name}'","account":{"id":"'${account_id}'"},"type": "full"}'
        RESPONSE="$(/bin/echo "Authorization: Bearer ${api_token}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X POST "${endpoint}" -H "Content-Type: application/json" --data "${json_payload}" 2>&1)"
else
        json_payload='{"name":"'${zone_name}'"}'
        RESPONSE="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X POST "${endpoint}" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json" --data "${json_payload}" 2>&1)"
fi
CURL_EXIT="$?"
set -e

if [ "${CURL_EXIT}" -ne 0 ]
then
        status "Error: curl failed with exit code ${CURL_EXIT} while creating zone ${zone_name}."
        status "Detail: ${RESPONSE}"
        exit 1
fi

# Separate the HTTP status code and JSON response body
HTTP_CODE="$(/bin/echo "${RESPONSE}" | /usr/bin/grep '^HTTP_STATUS:' | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/^HTTP_STATUS:/d')"

# Evaluate HTTP status code and emit response JSON on success
case "${HTTP_CODE}" in
        200|201)
                /bin/echo "${RESPONSE_BODY}"
                exit 0
                ;;
        400)
                status "Error 400: Bad Request. Check zone_name (${zone_name}) syntax or domain validity."
                status "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
        401)
                status "Error 401: Unauthorized. Your Cloudflare API token or credentials are invalid."
                exit 1
                ;;
        403)
                status "Error 403: Forbidden. Credentials lack permission to create zones."
                exit 1
                ;;
        404)
                status "Error 404: Not Found. The requested Cloudflare API endpoint could not be found."
                status "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
        429)
                status "Error 429: Rate Limit Exceeded. Back off request frequency."
                exit 1
                ;;
        5*)
                status "Error ${HTTP_CODE}: Cloudflare API or Upstream Server Exception."
                status "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
        *)
                status "Error ${HTTP_CODE:-UNKNOWN}: Unexpected response from Cloudflare API."
                status "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
esac


