#!/bin/sh
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
        status "Error: Zone name parameter is required."
        status "Usage: $0 <zone_name>"
        exit 1
fi

zone_name="${1}"

# Extract structural configuration contexts securely via modern subshells
DNS_CHOICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE)"
# Determine authentication layout structure and execute API endpoint communication safely


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
response="$(${BUILD_HOME}/services/dns/cloudflare/${orchestration_tool}/get_zone_id.sh "${zone_name}")"
set -e


# Verify final transaction payload state explicitly to catch schema rejections or token faults
if /bin/echo "${response}" | /usr/bin/jq -e '.success == false or .errors and (.errors | length > 0)' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[].message // "Unknown Cloudflare zone lookup validation error."')"
        status "Failed to look up zone ID for domain ${zone_name}. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

# Extract the matching unique domain layout zone ID cleanly
zone_id="$(/bin/echo "${response}" | /usr/bin/jq -r '.result[].id // empty')"

if [ -z "${zone_id}" ]
then
        status "No active zones found matching name '${zone_name}' in the DNS system."
        exit 1
fi

/bin/echo "${zone_id}"
exit 0
