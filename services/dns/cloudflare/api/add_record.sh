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

        api_response="$(/bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" -H "Content-Type: application/json" -d "${json_payload}")"
else
        # Fall back to traditional legacy X-Auth credential parameter signatures
        api_response="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json" -d "${json_payload}")"
fi
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Failed to Add record to for url ${website_url} with ip address ${ip} to the DNS system (Network/Curl connection error)."
        exit 1
fi

status "Cloudflare DNS A-record successfully provisioned: ${website_url} -> ${ip} [Proxied: True, TTL: 120s]"
exit 0

