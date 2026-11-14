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
        status "Error: website_url and zone_id parameters are required."
        status "Usage: $0 <website_url> <zone_id>"
        exit 1
fi

website_url="${1}"
zone_id="${2}"

DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"
DNS_SECURITY_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_SECURITY_KEY)"

set +e

if /bin/echo "${DNS_SECURITY_KEY}" | /bin/grep -q ':::'
then
        # Parse out isolated API token authorization strings cleanly
        api_token="$(/bin/echo "${DNS_SECURITY_KEY}" | /usr/bin/awk -F':::' '{print $2}')"

        api_response="$(/bin/echo "Authorization: Bearer ${api_token}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${website_url}" -H "Content-Type: application/json")"
else
        # Fall back to traditional legacy X-Auth credential parameter signatures
        api_response="$(/bin/echo "X-Auth-Key: ${DNS_SECURITY_KEY}" | curl -H @- -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=A&name=${website_url}" -H "X-Auth-Email: ${DNS_USERNAME}" -H "Content-Type: application/json")"
fi
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Failed to get record ids for record id ${record_id} (Network/Curl connection error)."
        exit 1
fi
# Extract the matching unique domain layout record IDs cleanly
record_ids="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.result[].id // empty')"

if [ -z "${record_ids}" ]
then
        status "No active A-records found matching name '${website_url}' inside zone '${zone_name}'."
        exit 1
fi

/bin/echo "${record_ids}"

exit 0

/bin/echo "${record_ids}"
exit 0

