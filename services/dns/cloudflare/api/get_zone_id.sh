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
if [ -z "${1}" ] 
then
        status "Error: zone_name parameter is required."
        status "Usage: $0 <zone_name>"
        exit 1
fi

zone_name="${1}"

DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"
DNS_SECURITY_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_SECURITY_KEY)"

set +e
if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        # Parse out isolated API token authorization strings cleanly
        api_token="$(/bin/echo "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $2}')"
        result="$(/bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "Content-Type: application/json")"
else
        # Fall back to traditional legacy X-Auth credential parameter signatures
        result="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json")"
fi
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${result}" ]
then
        status "Failed to query zone ID for domain ${zone_name} (Network/Curl connection error)."
        exit 1
fi

zone_id="$(/bin/echo "${result}" | /usr/bin/jq -r '.result[].id // empty')"

if [ -z "${zone_id}" ]
then
        status "No active zones found matching name '${zone_name}' in the DNS system."
        exit 1
fi

/bin/echo "${zone_id}"

exit 0



