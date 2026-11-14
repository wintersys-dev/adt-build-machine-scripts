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
        status "Error: Website URL parameter is required."
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
if [ -z "${DNS_CHOICE}" ] 
then
        status "Error: Failed to fetch required context variables (TOKEN)."
        exit 1
fi

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
record_ids="$(${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/get_all_record_ids.sh "${website_url}" "${zone_id}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Failed get record ids for domain ${website_url} (Network/Curl infrastructure execution error)."
        exit 1
fi


if [ "${exit_code}" -ne 0 ] || [ -z "${record_ids}" ]
then
        status "Failed to ${website_url} (Network/Curl connection error)."
        exit 1
fi

/bin/echo "${record_ids}"


exit 0
