#!/bin/sh
###################################################################################
# @file        GetAllRecordIDs.sh
# @brief       Routes DNS record ID retrieval requests to specialized backend scripts.
# @author      Peter Winter
# @date        10/11/2026
# @version     2.0
#
# @details     This script evaluates a target website URL and authority constraints to
#              determine the designated provider context. It maps the active deployment
#              strategy against centralized hardware and software configurations before
#              handing off execution to target providers to fetch matching record identifiers.
#
# @param       $1  [Required] The target website Fully Qualified Domain Name or URL string.
# @param       $2  [Required] Authority flag validation parameter ("yes" / "no").
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - ${BUILD_HOME}/configuration/software.dat static asset properties.
#              - external dependencies: cat, awk, test
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Protects layout evaluation chains from unexpected multi-parameter expansions.
#
# @exit        0  Success: Underlying script executed cleanly and returned code 0.
# @exit        1  Failure: Missing context paths, configuration syntax bugs, or tool failures.
###################################################################################
# License Agreement:
# This file is part of The Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
####################################################################################
#set -x
set -e

if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

status () {
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: 2 arguments are required."
        status "Usage: $0 <website_url> <auth>"
        exit 1
fi

website_url="${1}"
auth="${2}"

DNS_CHOICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE)"

if [ "${auth}" = "yes" ]
then
        DNS_CHOICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_DNS_CHOICE)"
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

script_path="${BUILD_HOME}/services/dns/${DNS_CHOICE}/GetAllRecordIDs.sh"

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
"${script_path}" "${website_url}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ]
then
        status "Error: GetAllRecordIDs.sh failed with exit code ${exit_code}"
        exit "${exit_code}"
fi

exit 0

