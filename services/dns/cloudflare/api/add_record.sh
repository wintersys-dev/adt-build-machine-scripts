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

zone_id="${1}"
json_payload="${2}"

DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"
DNS_SECURITY_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_SECURITY_KEY)"

set +e
if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        # Parse out isolated API token authorization strings cleanly
        api_token="$(/bin/echo "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $2}')"

        RESPONSE="$(/bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" -H "Content-Type: application/json" -d "${json_payload}")"
else
        # Fall back to traditional legacy X-Auth credential parameter signatures
        RESPONSE="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json" -d "${json_payload}")"
fi
set -e

# Extract the HTTP status code (e.g., 200, 400, 401) using strict POSIX filtering
HTTP_CODE=$(/bin/echo "$RESPONSE" | /usr/bin/grep "HTTP_STATUS:" | /usr/bin/cut -d':' -f2)

# Extract the raw response body by dropping the status delimiter line
RESPONSE_BODY=$(/bin/echo "$RESPONSE" | /usr/bin/sed '/HTTP_STATUS:/d')

# Evaluate the API response code using strict POSIX structural matching
case "${HTTP_CODE}" in
    200)
        # Safely parse out the raw data array from the verified response block and output to stdout
        /bin/echo "${RESPONSE_BODY}"
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




