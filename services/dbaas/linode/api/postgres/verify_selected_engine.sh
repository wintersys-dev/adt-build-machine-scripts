#!/bin/sh
#: Name:        VerifySelectedEngine.sh
#: Purpose:     Validates chosen database engine compatibility against Linode's DBaaS catalog.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       VerifySelectedEngine.sh
#:              VerifySelectedEngine.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads DATABASE_DBaaS_INSTALLATION_TYPE and TOKEN via GetVariableValue.sh.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, awk, curl, jq
#:
#: Exit Codes:
#:   0          Target database engine successfully verified against cloud catalog
#:   1          Missing configuration contexts, API errors, or unsupported engine
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

# Retrieve DBaaS installation profile and authentication token from active context
DATABASE_DBaaS_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_DBaaS_INSTALLATION_TYPE)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Extract the target engine identifier string from the 3rd colon-delimited field
engine="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $3}')"

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/databases/engines"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Query available managed database engines with token passed securely via stdin
set +e
api_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s "${endpoint}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Failed to obtain list of available engines (Network/Curl infrastructure execution error)."
        exit 1
fi

# Inspect the returned JSON payload for Linode API error objects
if /bin/echo "${api_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[0].reason // .errors.reason // "Unknown API error parameters."')"
        status "Failed to obtain engine list. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

# Extract all supported engine IDs from the returned catalog payload
available_engines="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.data[].id // empty')"

if [ -z "${available_engines}" ]
then
        status "Failed to parse available engines from the cloud management catalog metadata."
        exit 1
fi

# Verify that the configured engine exists as an exact word match in the available list
set +e
/bin/echo "${available_engines}" | /bin/grep -q -w "${engine}"
match_code="$?"
set -e

if [ "${match_code}" -ne 0 ]
then
        status "The database engine you have selected (${engine}) is not available. Please correct and re-deploy."
        exit 1
fi

status "Database engine '${engine}' successfully verified against cloud catalog... OK to proceed."
exit 0

