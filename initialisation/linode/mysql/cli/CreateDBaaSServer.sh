#!/bin/sh
###################################################################################
# @file        CreateDBaaSServer.sh
# @brief       Provisions a managed Linode MySQL DBaaS server using the Linode CLI.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script extracts targeted cluster parameters from environment setup 
#              strings, configures private network access variables, flags credentials
#              securely, and triggers the provider CLI utility to spin up new infrastructure nodes.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh centralized configuration variable extraction tool.
#              - external dependencies: cat, echo, awk, linode-cli
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Replaces legacy, fragile backtick subshells with secure shell evaluations.
#              - Eliminates redundant subshell grouping fork performance bottlenecks.
#              - Scopes and purges sensitive tokens (LINODE_CLI_TOKEN) tightly inside execution tracks.
#
# @exit        0  Success: Target database server provision request transmitted safely via CLI.
# @exit        1  Failure: Missing context paths, input parameter errors, or binary failures.
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

#########################################################################################################
#DATABASE_DBaaS_INSTALLATION_TYPE="MySQL:DBAAS:<engine>:<region>:<machine_type>:<cluster_size>:<cluster_label>:<db_name>:<db_username>:<db_password>:<vpc_id>:<subnet_id>
#DATABASE_DBaaS_INSTALLATION_TYPE="MySQL:DBAAS:mysql/8:nl-ams:g6-nanode-1:1:test-cluster:testdb1:testdbuser:gdhf76gdfgsh:266632:266052"
#########################################################################################################

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
        public_access_flag="--private_network.public_access"
        public_access_val="true"
else
        public_access_flag="--private_network.public_access"
        public_access_val="false"
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

# Invoke deployment utility while tracking structural return codes manually
set +e
/usr/local/bin/linode-cli databases mysql-create --no-defaults --label "${label}" --region "${db_region}" --type "${machine_type}" --cluster_size "${cluster_size}" --engine "${engine}" --ssl_connection true --allow_list "0.0.0.0/0" --private_network.vpc_id "${vpc_id}" --private_network.subnet_id "${subnet_id}" "${public_access_flag}" "${public_access_val}"
exit_code="$?"
set -e

if [ "${exit_code}" -ne 0 ] 
then
        status "Failed to provision DBaaS server via Linode CLI."
        unset LINODE_CLI_TOKEN
        exit 1
fi

status "Database provision request successfully submitted via CLI for instance '${label}'."
unset LINODE_CLI_TOKEN

exit 0

