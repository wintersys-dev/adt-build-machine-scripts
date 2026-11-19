#!/bin/sh
####################################################################################
# Author: Peter Winter (ADT Convention)
# Description: Pre-deployment audit to detect 'set -x' / xtrace in toolkit scripts
# and abort the build if running in PRODUCTION mode.
####################################################################################

status () {
    /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
    script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
    /bin/echo "${script_name}: ${1}" >> /dev/fd/4
}

BUILD_HOME="`/bin/cat /home/buildhome.dat 2>/dev/null`"
BUILD_HOME="${BUILD_HOME:-$(pwd)}"

if [ ! -d "${BUILD_HOME}" ]; then
    status "Directory ${BUILD_HOME} not found, skipping xtrace audit."
    exit 0
fi

# Retrieve ADT mode flags via GetVariableValue.sh if available, otherwise fall back to environment
if [ -x "${BUILD_HOME}/helpers/services/GetVariableValue.sh" ]; then
    PRODUCTION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh PRODUCTION`"
    DEPLOYMENT_MODE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DEPLOYMENT_MODE`"
fi

# Scan all shell scripts across ${BUILD_HOME}
MATCHES="`/usr/bin/find "${BUILD_HOME}" -type f -name "*.sh" -exec /bin/grep -nE \
    '(^|[[:space:];])(set[[:space:]]+-[[:alpha:]]*x|set[[:space:]]+-o[[:space:]]+xtrace|#!/.*(ba)?sh[[:space:]]+-[[:alpha:]]*x)' \
    /dev/null {} +`"

if [ -n "${MATCHES}" ]; then
    status "################################################################################"
    status "WARNING: Shell debug tracing (set -x / xtrace) detected in the following scripts:"
    status "${MATCHES}"
    status "################################################################################"

    # ADT templates use PRODUCTION="1" or DEPLOYMENT_MODE="PRODUCTION" (note: ADT docs also reference typo "PRODUCTIOM")
    if [ "${PRODUCTION}" = "1" ] || [ "${DEPLOYMENT_MODE}" = "PRODUCTION" ] || [ "${DEPLOYMENT_MODE}" = "PRODUCTIOM" ]; then
        status "ERROR: Aborting deployment because xtrace is enabled while in PRODUCTION mode."
        exit 1
    else
        status "NOTICE: Continuing build because toolkit is in DEVELOPMENT mode."
        exit 0
    fi
fi

status "OK: No shell debug tracing detected across ${BUILD_HOME}."
exit 0
