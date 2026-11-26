#!/bin/sh
#: Name:        check_dbaas_service_status.sh
#: Purpose:     Monitors Linode DBaaS cluster status (MySQL or PostgreSQL) until active via REST API.
#: Author:      Peter Winter
#: Date:        24/11/2026
#: Version:     1.0
#:
#: Usage:       check_dbaas_service_status.sh
#:              check_dbaas_service_status.sh [-h|--help]
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
#:   - External binaries: cat, echo, grep, cut, awk, curl, jq, expr, sleep
#:
#: Exit Codes:
#:   0          Target database cluster verified in an active, running state
#:   1          Missing context paths, explicit platform failures, or polling timeout
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

# Configure polling retry ceiling (50 attempts x 20s = 1000 seconds max wait)
max_attempts=50
sleep_interval=20
attempt=1

status "Waiting for ${db_family} database '${label}' to become active..."

# Poll Linode Managed Databases API until the cluster reports 'active' or times out
while true
do
        # Query database instances with token passed securely via stdin; tolerate transient errors
        set +e
        api_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s --connect-timeout 15 --max-time 30 "${endpoint}")"
        db_status="$(/bin/echo "${api_response}" | /usr/bin/jq -r --arg lbl "${label}" '.data[]? | select(.label == $lbl).status // empty' 2>/dev/null || true)"
        set -e

        if [ -z "${db_status}" ]
        then
                status "Database '${label}' not found or API error. Retrying..."
        elif [ "${db_status}" = "active" ]
        then
                status "Database is ready and active!"
                break
        elif [ "${db_status}" = "failed" ] || [ "${db_status}" = "error" ]
        then
                status "Database deployment failed with status: ${db_status}"
                exit 1
        else
                status "Current status: '${db_status}' (Attempt ${attempt}/${max_attempts})..."
        fi

        # Abort cleanly if maximum polling attempts have been reached
        if [ "${attempt}" -ge "${max_attempts}" ]
        then
                total_wait_seconds="$(/usr/bin/expr "${max_attempts}" \* "${sleep_interval}")"
                status "Timed out waiting for database to become active after ${total_wait_seconds} seconds."
                exit 1
        fi

        # Increment attempt counter and sleep before the next poll
        attempt="$(/usr/bin/expr "${attempt}" + 1)"
        /bin/sleep "${sleep_interval}"
done

exit 0
