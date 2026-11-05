#!/bin/sh
###################################################################################
# @file        ObtainDatabaseDetails.sh
# @brief       Extracts configuration and connection payloads for a managed DBaaS instance.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script queries the cloud provider's instances and credentials 
#              endpoints to dynamically capture cluster endpoints, authorization strings, 
#              routing networks, and port identifiers. It validates runtime payloads 
#              defensively and prints an exportable shell-compatible configurations block.
#
# @param       $1  [Required] The unique platform identifier ID of the active database instance.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, curl, jq, sed
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Masks API interactions securely via stream piping using the @- syntax.
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

# Query active cluster endpoint details securely with manual intercept hooks to catch runtime exceptions
set +e
api_instance_json="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X GET "https://api.linode.com/v4/databases/mysql/instances/${database_id}")"
api_credentials_json="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X GET "https://linode.com{database_id}/credentials")"
set -e

# Parse API returns defensively using secure subshells
export database_id
export CLUSTER_NAME="$(/bin/echo "${api_instance_json}" | /usr/bin/jq -r '.label // empty')"
export DB_IDENTIFIER="$(/bin/echo "${api_instance_json}" | /usr/bin/jq -r '.hosts.primary // empty')"
export DB_USERNAME="$(/bin/echo "${api_credentials_json}" | /usr/bin/jq -r '.username // empty')"
export DB_PASSWORD="$(/bin/echo "${api_credentials_json}" | /usr/bin/jq -r '.password // empty')"
export DB_PORT="$(/bin/echo "${api_instance_json}" | /usr/bin/jq -r '.port // empty')"
export DB_NAME="${db_name}"

# Perform rigorous sanity checks over required parameters to ensure full alignment
for var_name in CLUSTER_NAME DB_IDENTIFIER DB_USERNAME DB_PASSWORD DB_PORT DB_NAME
do
        eval "var_val=\${$var_name}"
        if [ -z "${var_val}" ]
        then
                status "Error: Required variable '${var_name}' is not set, empty, or failed API lookup constraints."
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
DB_PORT='${DB_PORT}'
DB_NAME='${DB_NAME}'
EOF

exit 0
