#set -x
set -e


BUILDOS="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS`"
BUILDOS_VERSION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILDOS_VERSION`"

# Sourced application root tracking pathway string
if [ -r /home/homedir.dat ]
then
        HOME="$(/bin/cat /home/homedir.dat)"
else
        /bin/echo "Application root configuration file missing at /home/homedir.dat" >&2
        exit 1
fi

status () {
    ${HOME}/helpers/services/LogStatusMessages.sh "${1}" 2>/dev/null
}

cloudhost_file="${HOME}/runtime/ACTIVE_CLOUDHOST"
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

software_file="${HOME}/configuration/software.dat"
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

script_path="${HOME}/services/server/${CLOUDHOST}/${orchestration_tool}/GetOperatingSystemVersion.sh"

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
"${script_path}" "${BUILDOS}" "${BUILDOS_VERSION}"
exit_code=$?
set -e

if [ ${exit_code} -ne 0 ]
then
    status "Error: GetServerName.sh failed with exit code $exit_code"
    exit $exit_code
fi

exit 0
