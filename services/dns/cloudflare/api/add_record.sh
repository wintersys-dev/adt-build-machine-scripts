#!/bin/sh
#set -x
set -e

# Resolve BUILD_HOME baseline layout securely
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Input validation
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: zone_id and json_payload parameters are required."
        status "Usage: $0 <zone_id> <json_payload>"
        exit 1
fi

# Strip any accidental whitespace/newlines from zone_id to prevent curl exit code 3
zone_id="$(printf '%s' "${1}" | /usr/bin/tr -d '[:space:]')"
json_payload="${2}"

if [ -z "${zone_id}" ]
then
        status "Error: zone_id is empty after whitespace removal."
        exit 1
fi

DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"
DNS_SECURITY_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_SECURITY_KEY)"

API_URL="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"

# Build authentication headers and execute request
set +e
if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        api_token="$(/bin/echo "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $2}')"
        RESPONSE="$(/bin/echo'Authorization: Bearer %s\n' "${api_token}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X POST "${API_URL}" -H "Content-Type: application/json" -d "${json_payload}" 2>&1)"
else
        RESPONSE="$(/bin/echo 'X-Auth-Key: %s\n' "${DNS_SECURITY_KEY}" | /usr/bin/curl -H @- -sS -w "\nHTTP_STATUS:%{http_code}" -X POST "${API_URL}" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json" -d "${json_payload}" 2>&1)"
fi
CURL_EXIT=$?
set -e

if [ "${CURL_EXIT}" -ne 0 ]
then
        status "Error: curl failed with exit code ${CURL_EXIT}."
        status "Detail: ${RESPONSE}"
        exit 1
fi

# Extract HTTP status code and response body using strict POSIX filtering
HTTP_CODE="$(/bin/echo "${RESPONSE}" | /usr/bin/grep '^HTTP_STATUS:' | /usr/bin/cut -d':' -f2)"
RESPONSE_BODY="$(/bin/echo "${RESPONSE}" | /usr/bin/sed '/^HTTP_STATUS:/d')"

# Evaluate the API response code
case "${HTTP_CODE}" in
        200|201)
                /bin/echo '%s\n' "${RESPONSE_BODY}"
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




