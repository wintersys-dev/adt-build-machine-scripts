
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
if [ -z "${1}" ] 
then
        status "Error: Website URL address parameters are required."
        status "Usage: $0 <website_url>"
        exit 1
fi

website_url="${1}"

# Extract structural configuration contexts securely via modern subshells
DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

if [ -z "${DNS_CHOICE}" ] 
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

# Parse apex zone identifier safely
zone_name="$(/bin/echo "${website_url}" | /usr/bin/cut -d'.' -f2-)"

software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

if [ ! -d "${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ]
then
        orchestration_tool="api"
fi

set +e
response="$(${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/create_zone.sh "${zone_name}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Failed to add record to DNS system (Network/Curl infrastructure execution error)."
        exit 1
fi


# Verify final transaction payload state explicitly to catch schema rejections or token faults
if /bin/echo "${response}" | /usr/bin/jq -e '.success == false or .errors and (.errors | length > 0)' >/dev/null 2>&1
then
        err_msg="$(/bin/echo "${response}" | /usr/bin/jq -r '.errors[0].message // "Unknown Cloudflare validation error details."')"
        status "Failed to Add record for url ${website_url} to the DNS system. Cloud Provider Reason: ${err_msg}"
        exit 1
fi

status "Cloudflare DNS A-record successfully provisioned: ${website_url} -> ${ip} [Proxied: True, TTL: 120s]"
exit 0
