set -x
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
        status "Error: Record ID and Website URL parameters are required."
        status "Usage: $0 <record_id> <website_url>"
        exit 1
fi

record_id="${1}"
website_url="${2}"

# Extract structural configuration contexts securely via modern subshells
DNS_USERNAME="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_USERNAME)"
DNS_SECURITY_KEY="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_SECURITY_KEY)"
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

# Parse apex zone identifier safely using modern subshells
zone_name="$(/bin/echo "${website_url}" | /usr/bin/cut -d'.' -f2-)"

# Intercept and capture zone ID configurations cleanly
zone_id="$("${BUILD_HOME}/services/dns/GetZoneID.sh" "${zone_name}")"

if [ -z "${zone_id}" ]
then
        status "Zone ID empty for '${zone_name}'. Spawning authoritative zone layout..."
        "${BUILD_HOME}/services/dns/CreateZone.sh" "${website_url}"
        zone_id="$("${BUILD_HOME}/services/dns/GetZoneID.sh" "${zone_name}")"
        
        if [ -z "${zone_id}" ]
        then
                status "Error: Failed to verify zone ID allocation for '${zone_name}' after provisioning step."
                exit 1
        fi
fi


set +e
response="$(${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/delete_record.sh "${zone_id}" "${record_id}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Failed to add record to DNS system (Network/Curl infrastructure execution error)."
        exit 1
fi


if [ "${exit_code}" -ne 0 ] || [ -z "${response}" ]
then
        status "Failed to delete record from DNS system with id: ${record_id} and url: ${website_url} (Network/Curl connection error)."
        exit 1
fi

# Verify final transaction payload state explicitly to catch schema rejections or token faults
if /bin/echo "${response}" | /usr/bin/jq -e '.success == false or .errors and (.errors | length > 0)' >/dev/null 2>&1
then
        err_msg="$(/bin/echo "${response}" | /usr/bin/jq -r '.errors[0].message // "Unknown Cloudflare entry deletion validation error."')"
        status "Failed to delete record from DNS system. Cloud Provider Reason: ${err_msg}"
        exit 1
fi

status "Cloudflare DNS record entry successfully expunged: ID ${record_id} removed from zone ${zone_name}."
exit 0
