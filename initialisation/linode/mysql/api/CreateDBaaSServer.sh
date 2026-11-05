#!/bin/sh
###################################################################################
# @file        CreateDBaaSServer.sh
# @brief       Provisions a managed Linode MySQL DBaaS server within a specified VPC.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script extracts targeted cluster parameters from environment setup 
#              strings, configures network access states, issues a secure POST 
#              transaction payload to the provider API framework, and captures exit codes 
#              manually to guarantee data validation.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, curl
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Masks API interactions securely via stream piping using the @- syntax.
#
# @exit        0  Success: Target database server provision request transmitted safely.
# @exit        1  Failure: Missing context paths or API communication failures.
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

# Framework deployment variables extraction using secure subshells
DATABASE_DBaaS_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_DBaaS_INSTALLATION_TYPE)"
MULTI_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" MULTI_REGION)"
PRIMARY_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" PRIMARY_REGION)"
TOKEN="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" TOKEN)"

# Extract targeted database configuration details from parsing matrix strings
engine="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $3}')"
cluster_size="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $6}')" 
db_region="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $4}')"
machine_type="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $5}')"
label="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $7}')"
vpc_id="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $11}')"
subnet_id="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $12}')"

# Determine private network accessibility logic boundaries cleanly
if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ]
then
        public_access="true"
else
        public_access="false"
fi

# Assemble raw JSON transaction variables block defensively
# Note: JSON payload structure dynamically embeds numeric integers (cluster_size, vpc_id, subnet_id) 
# and boolean properties (public_access) alongside double-quoted context string values.
json_payload="$(/bin/cat <<EOF
{
  "label": "${label}",
  "region": "${db_region}",
  "type": "${machine_type}",
  "engine": "${engine}",
  "cluster_size": ${cluster_size},
  "ssl_connection": true,
  "allow_list": ["0.0.0.0/0"],
  "private_network": {
    "vpc_id": ${vpc_id},
    "subnet_id": ${subnet_id},
    "public_access": ${public_access}
  }
}
EOF
)"

# Execute provision endpoint communication safely while manual intercept hooks track faults
set +e
api_response="$(/bin/echo "Authorization: Bearer ${TOKEN}" | curl -H @- -s -X POST "https://api.linode.com/v4/databases/mysql/instances" -H "Content-Type: application/json" -d "${json_payload}")"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] 
then
        status "Failed to provision DBaaS server (Network/Curl infrastructure execution error)."
        exit 1
fi

# Verify payload returns to protect against downstream status failures
if /bin/echo "${api_response}" | /usr/bin/jq -e '.errors' >/dev/null 2>&1
then
        api_err_msg="$(/bin/echo "${api_response}" | /usr/bin/jq -r '.errors[0].reason' 2>/dev/null || /bin/echo "Unknown API error pattern structure.")"
        status "Failed to provision DBaaS server. Cloud Provider Reason: ${api_err_msg}"
        exit 1
fi

status "Database provision request successfully submitted for instance '${label}'."
exit 0

