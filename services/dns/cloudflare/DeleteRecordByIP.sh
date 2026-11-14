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

if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: website_url and ip parameters are required." 
        status "Usage: $0 <website_url> <ip>" 
        exit 1
fi

website_url="${1}"
ip="${2}"

set +e
DNS_CHOICE="$(${BUILD_HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

software_file="${BUILD_HOME}/runtime/software.dat"
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
${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/delete_record_by_ip.sh "${website_url}" "${ip}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] 
then
        status "Failed to delete record ${record_id} domain ${website_url} for ip address ${ip}"
        exit 1
fi

/bin/echo "DNS record successfully deleted: ${website_url}"
exit 0
