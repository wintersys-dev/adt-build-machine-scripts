#!/bin/sh
###################################################################################
# @file        GetOperatingSystemVersion.sh
# @brief       Orchestrates cloud-provider specific operating system version resolution.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script pulls active OS and version mappings from the environment,
#              identifies the active cloud architecture landscape, dynamically maps 
#              execution paths to provider-specific slug wrappers, and handles 
#              exit transaction state codes manually within safe checking bounds.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active framework layout.
#              - LogStatusMessages.sh utility logging system messages.
#              - GetVariableValue.sh centralized wrapper for lookup configurations.
#              - ${BUILD_HOME}/runtime/ACTIVE_CLOUDHOST state tracking descriptor file.
#              - ${BUILD_HOME}/configuration/software.dat toolkit software configuration registry.
#              - external dependencies: cat, echo
#
# @security    
#              - Hardens system-owned paths (/bin) to eliminate executable hijack vectors.
#              - Replaces fragile backtick subshells with secure shell evaluations.
#              - Quotes variable interpolations thoroughly to trap space-injection hazards.
#              - Isolates runtime subprocess transaction state codes manually within safe bounds.
#
# @exit        0  Success: Operating system distribution translation slug resolved cleanly.
# @exit        *  Failure: Runtime path verification error, broken configurations, or bubbling
#                 exit code failures generated directly by the underlying execution script.
###################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
####################################################################################
set -e

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

BUILDOS="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILDOS)"
BUILDOS_VERSION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILDOS_VERSION)"

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

script_path="${BUILD_HOME}/services/server/${CLOUDHOST}/GetOperatingSystemVersion.sh"

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
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Error: GetOperatingSystemVersion.sh failed with exit code ${exit_code}." >&2
        exit "${exit_code}"
fi

exit 0

