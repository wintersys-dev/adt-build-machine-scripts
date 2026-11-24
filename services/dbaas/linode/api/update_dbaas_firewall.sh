#!/bin/sh
#: Name:        update_dbaas_firewall.sh
#: Purpose:     Updates the network firewall allow list for a managed Linode DBaaS cluster (MySQL or PostgreSQL).
#: Author:      Peter Winter
#: Date:        24/11/2026
#: Version:     2.0
#:
#: Usage:       update_dbaas_firewall.sh <database_id> <allow_list>
#:              update_dbaas_firewall.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique Linode platform identifier ID of the active database instance.
#:   $2         [Required] Comma-separated IP/CIDR allow list string (e.g. "10.0.0.0/24" or "0.0.0.0/0").
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
#:   0          Target database network access control rules modified cleanly
#:   1          Missing context paths, parameter validation error, or API failure
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

# Validate that both database ID and allow list arguments were provided
if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: Database ID and allow_list parameters are required."
        status "Usage: $0 <database_id> <allow_list>"
        exit 1
fi

database_id="${1}"
allow_list_raw="${2}"

# Retrieve DBaaS specification string and authentication token from the active deployment context
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

# Convert the comma-separated CIDR string into a trimmed JSON allow_list array safely via jq
json_payload="$(/bin/echo "${allow_list_raw}" | /usr/bin/jq -R 'split(",") | map(gsub("^[ \t\n\r]+|[ \t\n\r]+$"; "")) | {allow_list: .}' 2>/dev/null)"

if [ -z "${json_payload}" ]
then
        status "Error: Failed to generate a valid network configuration payload array from: ${allow_list_raw}"
        exit 1
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/databases/${db_type}/instances/${database_id}"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Submit the firewall allow list PUT update with token passed securely via stdin
set +e
api_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s --connect-timeout 15 --max-time 30 -X PUT "${endpoint}" -H "Content-Type: application/json" -d "${json_payload}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Database ${database_id} firewall allow list failed to update (Network/Curl infrastructure execution error)."
        exit 1
fi

# Inspect the returned JSON payload for Linode API error objects
if /bin/echo "${api_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[0].reason // .errors.reason // "Unknown API error parameters."')"
        status "Database ${database_id} firewall allow list update rejected. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

status "Database ${database_id} firewall access network settings successfully modified."
exit 0
