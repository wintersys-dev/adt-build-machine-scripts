#set -x
set -e

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}" 2>/dev/null
}

# 1. Check for the required argument safely
if [ -z "$1" ]
then
        status "Error: Build Machine IP address argument is required."
        status "Usage: $0 <buildmachine_ip>" 
        exit 1
fi

buildmachine_ip="$1"

cloudhost_file="${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST"
if [ ! -f "${cloudhost_file}" ] || [ ! -r "${cloudhost_file}" ]
then
        status "Error: Cannot read active cloud host file at ${cloudhost_file}"
        exit 1
fi

CLOUDHOST="$(/bin/cat "${cloudhost_file}")"

if [ -z "${CLOUDHOST}" ]
then
        status "Error: CLOUDHOST variable is empty."
        exit 1
fi

software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}" 
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}" 2>/dev/null | /bin/tr -d ' ')"

if [ -z "${orchestration_tool}" ]
then
        status "Error: ORCHESTRATION_TOOL not found in ${software_file}"
        exit 1
fi

script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/CheckBuildMachineVPC.sh"

if [ ! -f "${script_path}" ]
then
        status "Error: Script not found at ${script_path}" 
        exit 1
fi

if [ ! -x "${script_path}" ]
then
        status "Error: Script at ${script_path} is not executable."
        exit 1
fi

set +e
"${script_path}" "${buildmachine_ip}"
exit_code=$?
set -e

if [ ${exit_code} -ne 0 ]
then
        status "Error: GetServerName.sh failed with exit code $exit_code"
        exit $exit_code
fi

exit 0
