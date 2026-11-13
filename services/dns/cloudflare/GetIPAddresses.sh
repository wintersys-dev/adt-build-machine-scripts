set -e

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

if [ -z "${1}" ] 
then
        /bin/echo "Error: Fully Qualified Domain Name is required." >&2
        /bin/echo "Usage: $0 <fqdn> " >&2
        exit 1
fi

website_url="${1}"

set +e
DNS_CHOICE="$(${HOME}/utilities/config/ExtractConfigValue.sh 'DNSCHOICE')"
set -e

software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        /bin/echo "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

if [ -z "${orchestration_tool}" ] 
then
        /bin/echo "Error: ORCHESTRATION_TOOL not found in ${software_file}" >&2
        exit 1
fi

if [ ! -d "${BUILD_HOME}/services/dns/${DNS_CHOICE}/${orchestration_tool}" ] 
then
        orchestration_tool="api"
fi

set +e
${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/get_ip_addresses.sh "${website_url}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] 
then
        /bin/echo "Failed to get ip addresses for domain ${website_url}" >&2
        exit 1
fi

exit 0
