set -e

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

if [ -z "${1}" ] 
then
        status "Error: Zone Name is required" 
        status "Usage: $0 <zone_name>" 
        exit 1
fi

zone_name="${1}"

DNS_CHOICE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DNS_CHOICE)"

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
${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/get_zone_id.sh "${zone_name}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] 
then
        status "Failed to get zone id is for zone name ${zone_name}"
        exit 1
fi

exit 0
