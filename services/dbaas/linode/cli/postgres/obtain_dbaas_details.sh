#!/bin/sh
###################################################################################
# @file        obtain_dbaas_details.sh
# @brief       Extracts configuration payloads for a managed DBaaS instance via CLI.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script queries the cloud provider's databases and credentials 
#              catalog utilizing the Linode CLI, captures variables natively into jq
#              isolated pipelines, processes network scope mutations, and outputs a 
#              clean, exportable shell-compatible configurations block.
#
# @param       $1  [Required] The unique platform identifier ID of the active database instance.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, linode-cli, jq, sed
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Scopes and purges sensitive tokens (LINODE_CLI_TOKEN) tightly inside execution tracks.
#
# @exit        0  Success: Runtime database engine parameter variables resolved and emitted.
# @exit        1  Failure: Missing context parameters or target property extraction faults.
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
set -e

# Resolve BUILD_HOME baseline layout securely
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

# Input validation
if [ -z "${1}" ]
then
        status "Error: Database ID parameter is required."
        status "Usage: $0 <database_id>"
        exit 1
fi

database_id="${1}"

# Framework deployment variables extraction using secure subshells
DATABASE_DBaaS_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_DBaaS_INSTALLATION_TYPE)"
MULTI_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" MULTI_REGION)"
PRIMARY_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" PRIMARY_REGION)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Extract targeted database connection parameters from configuration strings
db_name="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $8}')"
db_username="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $9}')"
db_password="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $10}')"

# Determine private network accessibility logic boundaries cleanly
if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ]
then
        db_scope_prefix="public-"
else
        db_scope_prefix=""
fi

# Export authentication credentials safely within bounded local environment execution tracks
export LINODE_CLI_TOKEN="${TOKEN}"

# Validate CLI execution dependencies before invoking structural deployment steps
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        unset LINODE_CLI_TOKEN
        exit 1
fi

# Query active cluster endpoint details securely with manual intercept hooks to catch runtime exceptions
# Optimizes overhead from 5 sequential heavy CLI requests down to 2 optimized payload extractions
set +e
cli_instance_json="$("/usr/local/bin/linode-cli" databases postgresql-list --no-defaults --json 2>/dev/null)"
cli_credentials_json="$("/usr/local/bin/linode-cli" databases postgresql-creds-view "${database_id}" --no-defaults --json 2>/dev/null)"
set -e

unset LINODE_CLI_TOKEN

# Parse database specifications safely via clean variables encapsulation metrics mapping
export database_id
CLUSTER_NAME="$(/bin/echo "${cli_instance_json}" | /usr/bin/jq -r --arg id "${database_id}" '.[] | select(.id == ($id | tonumber)) | .label // empty')"
DB_IDENTIFIER="$(/bin/echo "${cli_instance_json}" | /usr/bin/jq -r --arg id "${database_id}" '.[] | select(.id == ($id | tonumber)) | .hosts.primary // empty')"
DB_USERNAME="$(/bin/echo "${cli_credentials_json}" | /usr/bin/jq -r '.[].username // empty')"
DB_PASSWORD="$(/bin/echo "${cli_credentials_json}" | /usr/bin/jq -r '.[].password // empty')"
DB_PORT="$(/bin/echo "${cli_instance_json}" | /usr/bin/jq -r --arg id "${database_id}" '.[] | select(.id == ($id | tonumber)).port // empty')"
DB_NAME="${db_name}"

# Perform rigorous sanity checks over required parameters to ensure full alignment
for var_name in CLUSTER_NAME DB_IDENTIFIER DB_USERNAME DB_PASSWORD DB_PORT DB_NAME
do
        eval "var_val=\${$var_name}"
        if [ -z "${var_val}" ]
        then
                status "Error: Required variable '${var_name}' is not set, empty, or failed CLI lookup constraints."
                exit 1
        fi
done

# Adapt the private endpoint routing matrix dynamically if cross-region public routing flags match
if [ -n "${db_scope_prefix}" ]
then
        DB_IDENTIFIER="$(/bin/echo "${DB_IDENTIFIER}" | /bin/sed "s/^private-/${db_scope_prefix}/")"
fi

# Concat system admin configuration credentials with application access parameters
export DB_USERNAME="${DB_USERNAME}:::${db_username}"
export DB_PASSWORD="${DB_PASSWORD}:::${db_password}"

# Emit compliant environment configuration layout block safely
/bin/cat <<EOF
CLUSTER_NAME='${CLUSTER_NAME}'
DB_IDENTIFIER='${DB_IDENTIFIER}'
DB_USERNAME='${DB_USERNAME}'
DB_PASSWORD='${DB_PASSWORD}'
# Checked at: 2026-11-05 13:14:00
DB_PORT='${DB_PORT}'
DB_NAME='${DB_NAME}'
EOF

exit 0
