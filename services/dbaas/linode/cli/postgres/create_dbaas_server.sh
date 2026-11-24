#!/bin/sh
#: Name:        create_dbaas_server.sh
#: Purpose:     Provisions a managed Linode PostgreSQL DBaaS server within a VPC via linode-cli.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.1
#:
#: Usage:       create_dbaas_server.sh
#:              create_dbaas_server.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads DATABASE_DBaaS_INSTALLATION_TYPE, MULTI_REGION, PRIMARY_REGION, and TOKEN.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - External binaries: cat, echo, grep, cut, awk, linode-cli
#:
#: Exit Codes:
#:   0          Target database server provision request transmitted safely via CLI
#:   1          Missing context paths, missing CLI binary, or execution failure
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

#########################################################################################################
#DATABASE_DBaaS_INSTALLATION_TYPE="Postgres:DBAAS:<engine>:<region>:<machine_type>:<cluster_size>:<cluster_label>:<db_name>:<db_username>:<db_password>:<vpc_id>:<subnet_id>
#DATABASE_DBaaS_INSTALLATION_TYPE="Postgres:DBAAS:postgresql/16:nl-ams:g6-nanode-1:1:test-cluster:testdb1:testdbuser:gdhf76gdfgsh:266632:266052"
#########################################################################################################

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

# Parse colon-delimited cluster attributes from DATABASE_DBaaS_INSTALLATION_TYPE
# Format: Postgres:DBAAS:<engine>:<region>:<machine_type>:<cluster_size>:<cluster_label>:<db_name>:<db_username>:<db_password>:<vpc_id>:<subnet_id>
engine="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $3}')"
db_region="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $4}')"
machine_type="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $5}')"
cluster_size="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $6}')"
label="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $7}')"
vpc_id="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $11}')"
subnet_id="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $12}')"

# Validate all required cluster attributes before executing CLI creation
if [ -z "${engine}" ] || [ -z "${db_region}" ] || [ -z "${machine_type}" ] || [ -z "${cluster_size}" ] || [ -z "${label}" ] || [ -z "${vpc_id}" ] || [ -z "${subnet_id}" ]
then
        status "Error: Missing required cluster attributes in DATABASE_DBaaS_INSTALLATION_TYPE."
        exit 1
fi

# Enable public VPC access only when acting as the primary hub in a multi-region topology
public_access_flag="--private_network.public_access"
if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ]
then
        public_access_val="true"
else
        public_access_val="false"
fi

# Verify that the linode-cli binary is installed and executable
if [ ! -x /usr/local/bin/linode-cli ]
then
        status "Error: Linode CLI binary missing or not executable at /usr/local/bin/linode-cli"
        exit 1
fi

# Export authentication token temporarily for linode-cli execution
export LINODE_CLI_TOKEN="${TOKEN}"

# Dispatch PostgreSQL DBaaS creation via linode-cli with errexit paused to capture output and exit code
set +e
cli_output="$(/usr/local/bin/linode-cli databases postgresql-create --no-defaults \
        --label "${label}" \
        --region "${db_region}" \
        --type "${machine_type}" \
        --cluster_size "${cluster_size}" \
        --engine "${engine}" \
        --ssl_connection true \
        --allow_list "0.0.0.0/0" \
        --private_network.vpc_id "${vpc_id}" \
        --private_network.subnet_id "${subnet_id}" \
        "${public_access_flag}" "${public_access_val}" 2>&1)"
exit_code="$?"
set -e

# Clear the sensitive token variable immediately after the CLI call finishes
unset LINODE_CLI_TOKEN

if [ "${exit_code}" -ne 0 ]
then
        status "Failed to provision DBaaS server via Linode CLI. Reason: ${cli_output}"
        exit 1
fi

status "Database provision request successfully submitted via CLI for instance '${label}'."
exit 0


