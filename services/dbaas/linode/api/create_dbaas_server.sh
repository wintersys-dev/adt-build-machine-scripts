#!/bin/sh
#: Name:        create_dbaas_server.sh
#: Purpose:     Provisions a managed Linode DBaaS cluster (MySQL or PostgreSQL) within a VPC via API.
#: Author:      Peter Winter
#: Date:        24/11/2026
#: Version:     2.0
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
#:   - External binaries: cat, echo, grep, cut, awk, curl, jq
#:
#: Exit Codes:
#:   0          Target database server provision request transmitted safely
#:   1          Missing context paths, network faults, or provider API error response
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
#DATABASE_DBaaS_INSTALLATION_TYPE="<MySQL|Postgres>:DBAAS:<engine>:<region>:<machine_type>:<cluster_size>:<cluster_label>:<db_name>:<db_username>:<db_password>:<vpc_id>:<subnet_id>"
#DATABASE_DBaaS_INSTALLATION_TYPE="MySQL:DBAAS:mysql/8:nl-ams:g6-nanode-1:1:test-cluster:testdb1:testdbuser:gdhf76gdfgsh:266632:266052"
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

# Parse colon-delimited cluster attributes from DATABASE_DBaaS_INSTALLATION_TYPE
engine="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $3}')"
db_region="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $4}')"
machine_type="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $5}')"
cluster_size="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $6}')"
label="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $7}')"
vpc_id="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $11}')"
subnet_id="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $12}')"

if [ -z "${engine}" ] || [ -z "${db_region}" ] || [ -z "${machine_type}" ] || [ -z "${label}" ]
then
        status "Error: Missing required cluster attributes in DATABASE_DBaaS_INSTALLATION_TYPE."
        exit 1
fi

# Enable public VPC access only when acting as the primary hub in a multi-region topology
if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ]
then
        public_access="true"
else
        public_access="false"
fi

# Build the JSON provisioning request body safely via jq (validates integer/boolean types)
json_payload="$(/usr/bin/jq -n \
        --arg lbl "${label}" \
        --arg reg "${db_region}" \
        --arg typ "${machine_type}" \
        --arg eng "${engine}" \
        --argjson size "${cluster_size:-null}" \
        --argjson vpc "${vpc_id:-null}" \
        --argjson sub "${subnet_id:-null}" \
        --argjson pub "${public_access}" \
        '{
                label: $lbl,
                region: $reg,
                type: $typ,
                engine: $eng,
                cluster_size: $size,
                ssl_connection: true,
                allow_list: ["0.0.0.0/0"],
                private_network: {
                        vpc_id: $vpc,
                        subnet_id: $sub,
                        public_access: $pub
                }
        }' 2>/dev/null)"

if [ -z "${json_payload}" ] || [ -z "${cluster_size}" ] || [ -z "${vpc_id}" ] || [ -z "${subnet_id}" ]
then
        status "Error: Failed to generate a valid JSON provisioning payload (check numeric fields: cluster_size, vpc_id, subnet_id)."
        exit 1
fi

# Assemble endpoint from split components to prevent browser URL rewriting during copy-paste
api_sub="api"
api_domain="linode.com"
api_path="v4/databases/${db_type}/instances"
endpoint="https://${api_sub}.${api_domain}/${api_path}"

# Submit the DBaaS creation POST request with token passed securely via stdin
set +e
api_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | /usr/bin/curl -H @- -s --connect-timeout 15 --max-time 30 -X POST "${endpoint}" -H "Content-Type: application/json" -d "${json_payload}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] || [ -z "${api_response}" ]
then
        status "Failed to provision ${db_family} DBaaS server (Network/Curl infrastructure execution error)."
        exit 1
fi

# Inspect the returned JSON payload for Linode API error objects
if /bin/echo "${api_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[0].reason // .errors.reason // "Unknown API error pattern structure."')"
        status "Failed to provision ${db_family} DBaaS server. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

status "Database provision request (${db_family}) successfully submitted for instance '${label}'."
exit 0
