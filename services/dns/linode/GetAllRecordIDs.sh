#!/bin/sh
###################################################################################
# @file        GetAllRecordIDs.sh
# @brief       Resolves unique platform record identifiers for a targeted sub-domain node.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script parses a target Fully Qualified Domain Name (FQDN) to extract
#              its zone apex domain root and sub-domain fields, queries provider catalogs
#              securely to capture the parent zone ID, and searches the zone record entries
#              to output matching record IDs.
#
# @param       $1  [Required] The target Fully Qualified Domain Name (e.g., "www.domain.com").
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, cut, curl, jq
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Masks API interactions securely via stream piping using the @- syntax.
#              - Protects dynamic JSON queries from code parameter injection tracking bugs.
#
# @exit        0  Success: Target DNS record ID successfully resolved and printed.
# @exit        1  Failure: Missing context paths, input parameter errors, or API communication failures.
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

status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}"
}

if [ -z "${1}" ]
then
        status "Error: Fully Qualified Domain Name parameter is required."
        status "Usage: $0 <fqdn>"
        exit 1
fi

domain_url="$(/bin/echo "${1}" | /usr/bin/cut -d'.' -f2-)"
sub_domain="$(/bin/echo "${1}" | /usr/bin/awk -F'.' '{print $1}')"

TOKEN="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN)"
DNS_CHOICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE)"

software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
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

set +e
domain_json="$(${BUILD_HOME}/services/dns/linode/${orchestration_tool}/get_domains.sh)"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${domain_json}" ]
then
        status "Failed to query domain management catalog or network timeout occurred."
        exit 1
fi

if /bin/echo "${domain_json}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        err_msg="$(/bin/echo "${domain_json}" | /usr/bin/jq -r '.errors.reason // "Unknown API error parameters."')"
        status "Failed to retrieve domains list. Cloud Provider Reason: ${err_msg}"
        exit 1
fi

domain_id="$(${BUILD_HOME}/services/dns/linode/${orchestration_tool}/get_domain_id.sh "${domain_json}" "${domain_url}" )"

if [ -z "${domain_id}" ]
then
        status "Domain ID not found matching zone track string pattern: ${domain_url}"
        exit 1
fi

set +e
records_json="$(${BUILD_HOME}/services/dns/linode/${orchestration_tool}/get_record_ids.sh ${domain_id})"
records_exit_code="$?"
set -e

if [ "${records_exit_code}" -ne 0 ] || [ -z "${records_json}" ]
then
        status "Failed to get all record IDs from the DNS system for root domain ${domain_url} and sub domain ${sub_domain} (Network/Curl framework failure)."
        exit 1
fi

if /bin/echo "${records_json}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        records_err_msg="$(/bin/echo "${records_json}" | /usr/bin/jq -r '.errors.reason // "Unknown DNS records lookup validation error."')"
        status "Failed to look up records in the DNS system. Cloud Provider Reason: ${records_err_msg}"
        exit 1
fi

record_ids="$(/bin/echo "${records_json}" | /usr/bin/jq -r --arg sub "${sub_domain}" '.[] | select(.name == $sub) | .id // empty')"

if [ -z "${record_ids}" ]
then
        status "DNS Record ID not found matching sub-domain pattern '${sub_domain}' within zone '${domain_url}'."
        exit 1
fi

/bin/echo "${record_ids}"
exit 0
