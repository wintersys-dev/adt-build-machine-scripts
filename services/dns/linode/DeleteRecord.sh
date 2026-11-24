#!/bin/sh
#: Name:        DeleteRecord.sh
#: Purpose:     Deletes an active record entry from a specified Linode DNS domain zone matrix.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       DeleteRecord.sh <record_id> <fqdn>
#:              DeleteRecord.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique platform identifier ID of the target DNS record.
#:   $2         [Required] The Fully Qualified Domain Name context (e.g. "://example.com").
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/dns/linode/<orchestration_tool>/{get_domains,delete_record}.sh
#:   - External binaries: cat, echo, grep, cut, awk, jq
#:
#: Exit Codes:
#:   0          Target DNS record successfully deleted and verified
#:   1          Missing context paths, input parameter errors, or API/CLI failures
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
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

# Exit immediately if any command exits with a non-zero status
#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the system tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application framework configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

# Validate that both record ID and FQDN arguments were provided
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Record ID and Fully Qualified Domain Name parameters are required."
        status "Usage: $0 <record_id> <fqdn>"
        exit 1
fi

record_id="${1}"
domain_url="$(/bin/echo "${2}" | /usr/bin/cut -d'.' -f2-)"

# Read software.dat and resolve the active orchestration tool (cli or api)
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

# Query the Linode DNS domain catalog via the active orchestration wrapper
set +e
domain_json="$("${BUILD_HOME}/services/dns/linode/${orchestration_tool}/get_domains.sh")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        status "Failed to query domain management catalog or network timeout occurred."
        exit 1
fi

# Check the returned catalog payload for provider API error objects
if /bin/echo "${domain_json}" | /usr/bin/jq -e 'type == "object" and has("errors")' >/dev/null 2>&1
then
        err_msg="$(/bin/echo "${domain_json}" | /usr/bin/jq -r '.errors[0].reason // .errors.reason // "Unknown API error parameters."')"
        status "Failed to retrieve domains list. Cloud Provider Reason: ${err_msg}"
        exit 1
fi

# Extract the matching domain zone ID (supporting both API .data[] and CLI .[] JSON shapes)
domain_id="$(/bin/echo "${domain_json}" | /usr/bin/jq -r --arg dom "${domain_url}" '(if type == "object" and has("data") then .data else . end)[] | select(.domain | contains($dom)) | .id // empty' 2>/dev/null)"

if [ -z "${domain_id}" ]
then
        status "Domain ID not found matching zone track string pattern: ${domain_url}" 
        exit 1
fi

# Dispatch the record deletion request to the active orchestration wrapper
set +e
delete_response="$("${BUILD_HOME}/services/dns/linode/${orchestration_tool}/delete_record.sh" "${domain_id}" "${record_id}")"
delete_exit_code="$?"
set -e

if [ "${delete_exit_code}" -ne 0 ]
then
        status "Failed to delete record from DNS system (Network/Curl infrastructure execution error)."
        exit 1
fi

# Check the deletion response for provider API error objects
if [ -n "${delete_response}" ] && /bin/echo "${delete_response}" | /usr/bin/jq -e 'type == "object" and has("errors")' >/dev/null 2>&1
then
        delete_err_msg="$(/bin/echo "${delete_response}" | /usr/bin/jq -r '.errors[0].reason // .errors.reason // "Unknown DNS payload entry validation error."')"
        status "Failed to delete record from DNS system. Cloud Provider Reason: ${delete_err_msg}"
        exit 1
fi

status "DNS record ID ${record_id} successfully deleted from zone ${domain_url}."
exit 0

