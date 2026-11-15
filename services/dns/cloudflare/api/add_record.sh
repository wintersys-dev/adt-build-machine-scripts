#!/bin/sh
#: Name:        add_record.sh
#: Purpose:     Provisions a new DNS record within a Cloudflare zone via REST API.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       add_record.sh <zone_id> <json_payload>
#:              add_record.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique Cloudflare zone identifier ID.
#:   $2         [Required] The JSON payload defining the DNS record attributes.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, printf, tr, grep, cut, sed, awk, curl
#:
#: Exit Codes:
#:   0          Cloudflare DNS record created and JSON response emitted cleanly
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

# Validate that both zone_id and json_payload arguments were provided
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: zone_id and json_payload parameters are required."
        status "Usage: $0 <zone_id> <json_payload>"
        exit 1
fi

# Strip any accidental whitespace/newlines from zone_id to prevent curl URL syntax errors
zone_id="$(printf '%s' "${1}" | /usr/bin/tr -d '[:space:]')"
json_payload="${2}"

if [ -z "${zone_id}" ]
then
        status "Error: zone_id is empty after whitespace removal."
        exit 1
fi

# Retrieve Cloudflare authentication credentials from active deployment context
DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"
DNS_SECURITY_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_SECURITY_KEY)"
# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="cloudflare.com"
api_path="client/v4/zones/${zone_id}/dns_records"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Submit the DNS record creation POST request using Bearer token or legacy Global API Key
set +e
if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        api_token="$(/bin/echo "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $2}')"
        RESPONSE="$(/bin/echo "Authorization: Bearer ${api_token}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X POST "${endpoint}" --header "Content-Type: application/json" --data "${json_payload}" 2>&1)"
else
        RESPONSE="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X POST "${endpoint}" --header "X-Auth-Email: ${DNS_USERNAME}" --header "Content-Type: application/json" --data "${json_payload}" 2>&1)"
fi
CURL_EXIT="$?"
set -e

if [ "${CURL_EXIT}" -ne 0 ]
then
        status "Error: curl failed with exit code ${CURL_EXIT}."
        status "Detail: ${RESPONSE}"
        exit 1
fi

# Separate the HTTP status code and JSON response body
HTTP_CODE="$(/bin/echo "${RESPONSE}" | /usr/bin/grep '^HTTP_STATUS:' | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/^HTTP_STATUS:/d')"

# Evaluate HTTP status code and emit response JSON on success
case "${HTTP_CODE}" in
        200|201)
                printf '%s\n' "${RESPONSE_BODY}"
                exit 0
                ;;
        400)
                status "Error 400: Bad Request. Check JSON payload syntax or DNS record parameters."
                status "API Detail: ${RESPONSE_BODY}"
                exit 1
                ;;
        401)
                status "Error 401: Unauthorized. Your Cloudflare API token or credentials are invalid."
                exit 1
                ;;
        403)
                status "Error 403: Forbidden. Credentials lack permission to modify DNS records for this zone."
                exit 1
                ;;
        404)
                status "Error 404: Not Found. Verify that zone_id (${zone_id}) exists."
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





