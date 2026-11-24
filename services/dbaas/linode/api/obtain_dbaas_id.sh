#!/bin/sh
#: Name:        obtain_dbaas_id.sh
#: Purpose:     Resolves the Linode platform instance ID for a DBaaS cluster label (MySQL or PostgreSQL).
#: Author:      Peter Winter
#: Date:        24/11/2026
#: Version:     2.0
#:
#: Usage:       obtain_dbaas_id.sh
#:              obtain_dbaas_id.sh [-h|--help]
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
#:   0          Target cluster unique platform ID successfully resolved and printed
#:   1          Missing configuration contexts, API errors, or label mismatch
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

if [ -z "${DATABASE_DBaaS_INSTALLATION_TYPE}" ] || [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (DATABASE_DBaaS_INSTALLATION_TYPE or TOKEN)."
        exit 1
fi

# Resolve Linode API database family slug ('mysql' or 'postgresql') from Field 1
db_family="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $1}')"
case "${db_family}" in
        MySQL|mysql)
                db_type="mysql"
                ;;
        Postgres|PostgreSQL|postgres|postgresql)
                db_type="postgresql"
                ;;
        *)
                status "Error: Unsupported database family '${db_family}' in DATABASE_DBaaS_INSTALLATION_TYPE."
                exit 1
                ;;
esac

# Extract the target database cluster label from the 7th colon-delimited field
label="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $7}')"

if [ -z "${label}" ]
then
        status "Error: Missing cluster label in DATABASE_DBaaS_INSTALLATION_TYPE."
        exit 1
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/databases/${db_type}/instances"
endpoint="https://${api_sub}.${api_domain}/${api_path}?page_size=500"

# Query the Linode DBaaS instance catalog with token passed securely via stdin
set +e
api_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s --connect-timeout 15 --max-time 30 "${endpoint}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Failed to query cluster management catalog or network timeout occurred."
        exit 1
fi

if /bin/echo "${api_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[0].reason // .errors.reason // "Unknown API error parameters."')"
        status "Failed to query cluster management catalog. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

# Filter the returned cluster array safely via jq for the matching cluster label
database_id="$(/bin/echo "${api_response}" | /usr/bin/jq -r --arg lbl "${label}" '.data[] | select(.label == $lbl) | .id // empty')"

if [ -z "${database_id}" ]
then
        status "Database ID not available for label '${label}' (Instance not found or structural API fault)."
        exit 1
else
        /bin/echo "${database_id}"
fi

exit 0
