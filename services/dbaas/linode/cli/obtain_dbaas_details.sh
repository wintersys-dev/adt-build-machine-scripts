#!/bin/sh
#: Name:        obtain_dbaas_details.sh
#: Purpose:     Extracts connection details and credentials for a Linode DBaaS instance via CLI.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       obtain_dbaas_details.sh <database_id>
#:              obtain_dbaas_details.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] The unique Linode platform identifier ID of the active database instance.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, awk, linode-cli, jq, sed
#:
#: Exit Codes:
#:   0          Runtime database engine parameter variables resolved and emitted cleanly
#:   1          Missing context parameters or target property extraction faults
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

# Validate that the required target database instance ID argument was provided
if [ -z "${1}" ]
then
        status "Error: Database ID parameter is required."
        status "Usage: $0 <database_id>"
        exit 1
fi

database_id="${1}"

# Retrieve DBaaS specification string, multi-region flags, and API token from active context
DATABASE_DBaaS_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_DBaaS_INSTALLATION_TYPE)"
MULTI_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" MULTI_REGION)"
PRIMARY_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" PRIMARY_REGION)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

if [ -z "${DATABASE_DBaaS_INSTALLATION_TYPE}" ] || [ -z "${TOKEN}" ]
then
        status "Error: Failed to fetch required context variables (DATABASE_DBaaS_INSTALLATION_TYPE or TOKEN)."
        exit 1
fi

# Extract application-level database name, username, and password from the configuration string
db_name="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $8}')"
db_username="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $9}')"
db_password="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $10}')"

# Switch endpoint host prefix to 'public-' when operating as the primary hub in multi-region mode
if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ]
then
        db_scope_prefix="public-"
else
        db_scope_prefix=""
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

# Verify that the linode-cli binary is installed and executable
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        exit 1
fi

# Export authentication token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Query instance metadata and root credentials via linode-cli with errexit paused
set +e
cli_instance_json="$(/usr/local/bin/linode-cli databases mysql-list --no-defaults --json 2>/dev/null)"
inst_exit_code="$?"
cli_credentials_json="$(/usr/local/bin/linode-cli databases mysql-creds-view "${database_id}" --no-defaults --json 2>/dev/null)"
creds_exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI calls finish
unset LINODE_CLI_TOKEN

if [ "${inst_exit_code}" -ne 0 ] || [ -z "${cli_instance_json}" ]
then
        status "Failed to retrieve metadata for database ${database_id} via Linode CLI."
        exit 1
fi

if [ "${creds_exit_code}" -ne 0 ] || [ -z "${cli_credentials_json}" ]
then
        status "Failed to retrieve credentials for database ${database_id} via Linode CLI."
        exit 1
fi

# Parse cluster attributes and root credentials from the returned JSON payloads
CLUSTER_NAME="$(/bin/echo "${cli_instance_json}" | /usr/bin/jq -r --arg id "${database_id}" '.[] | select(.id == ($id | tonumber)) | .label // empty')"
DB_IDENTIFIER="$(/bin/echo "${cli_instance_json}" | /usr/bin/jq -r --arg id "${database_id}" '.[] | select(.id == ($id | tonumber)) | .hosts.primary // empty')"
DB_USERNAME="$(/bin/echo "${cli_credentials_json}" | /usr/bin/jq -r '.[].username // empty')"
DB_PASSWORD="$(/bin/echo "${cli_credentials_json}" | /usr/bin/jq -r '.[].password // empty')"
DB_PORT="$(/bin/echo "${cli_instance_json}" | /usr/bin/jq -r --arg id "${database_id}" '.[] | select(.id == ($id | tonumber)).port // empty')"
DB_NAME="${db_name}"

# Verify that every required connection attribute resolved to a non-empty value
for var_name in CLUSTER_NAME DB_IDENTIFIER DB_USERNAME DB_PASSWORD DB_PORT DB_NAME db_username db_password
do
        eval "var_val=\${$var_name}"
        if [ -z "${var_val}" ]
        then
                status "Error: Required variable '${var_name}' is not set, empty, or failed CLI lookup constraints."
                exit 1
        fi
done

# Rewrite the primary endpoint hostname prefix when cross-region public routing is active
if [ -n "${db_scope_prefix}" ]
then
        DB_IDENTIFIER="$(/bin/echo "${DB_IDENTIFIER}" | /bin/sed "s/^private-/${db_scope_prefix}/")"
fi

# Combine admin credentials with application-level credentials using the ':::' delimiter
DB_USERNAME="${DB_USERNAME}:::${db_username}"
DB_PASSWORD="${DB_PASSWORD}:::${db_password}"

# Emit shell-eval-compatible variable assignments to stdout for parent orchestrators
/bin/cat <<EOF
CLUSTER_NAME='${CLUSTER_NAME}'
DB_IDENTIFIER='${DB_IDENTIFIER}'
DB_USERNAME='${DB_USERNAME}'
DB_PASSWORD='${DB_PASSWORD}'
DB_PORT='${DB_PORT}'
DB_NAME='${DB_NAME}'
EOF

exit 0



