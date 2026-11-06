#!/bin/sh
###################################################################################
# @file        ProvisionDBaaS.sh
# @brief       Manages cloud DBaaS provisioning, credentials, and clustering architectures.
# @author      Peter Winter
# @date        05/11/2026
# @version     1.0
#
# @details     This script evaluates operational runtime profiles to either 
#              orchestrate cloud provider-managed DBaaS instances or instantiate 
#              secure, self-managed database infrastructure contexts. It manages 
#              firewall policy state adjustments, securely generates random secrets, 
#              synchronizes clustered configurations across cross-region data stores, 
#              and exports variables securely.
#
# @env         BUILD_HOME          Path to the toolkit core framework layout directory.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking active framework layout.
#              - LogStatusMessages.sh utility logging centralized system events.
#              - GetVariableValue.sh/SetVariableValue.sh global parameter state tools.
#              - external dependencies: cat, echo, awk, tr, openssl, cut, grep, mkdir
#
# @security    
#              - Hardens executable locations (/bin, /usr/bin) to negate path hijacking.
#              - Sanitizes and captures exit execution codes manually using strict checking bounds.
#
# @exit        0  Success: Target database engine and context configured and exported.
# @exit        1  Failure: Mismatched environment profiles, failed validation, or execution error.
##################################################################################
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
####################################################################################
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
CLOUDHOST="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" CLOUDHOST)"
DATABASE_INSTALLATION_TYPE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DATABASE_INSTALLATION_TYPE)"
DB_PORT="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DB_PORT)"
BUILD_IDENTIFIER="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_IDENTIFIER)"
BUILD_FROM_SNAPSHOT="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" BUILD_FROM_SNAPSHOT)"
MULTI_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" MULTI_REGION)"
PRIMARY_REGION="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" PRIMARY_REGION)"
DBaaS_PUBLIC_ENDPOINT="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DBaaS_PUBLIC_ENDPOINT)"
DEPLOYMENT_MODE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" DEPLOYMENT_MODE)"
WEBSITE_URL="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" WEBSITE_URL)"

# Structural validation of internal platform states
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

# Guard statement preventing non-production DBaaS configuration errors
if [ "${DEPLOYMENT_MODE}" = "DEVELOPMENT" ] && [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ]
then
        status "You are attempting to provision a managed database in development mode, this isn't supported you need to redeploy in production mode"
        exit 1
fi

# Orchestrate Cloud DBaaS Management Pipelines
if [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ] && { [ "${MULTI_REGION}" = "0" ] || { [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ]; }; }
then
        database_type_lower="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $1}' | /bin/tr '[:upper:]' '[:lower:]')"

        set +e
        "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/VerifySelectedEngine.sh"
        exit_code="$?"
        set -e
        
        if [ "${exit_code}" -ne 0 ] 
        then
                status "Database Engine not successfully verified"
                exit 1
        fi

        set +e
        database_id="$("${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/ObtainDatabaseID.sh")"
        exit_code="$?"
        set -e

        if [ "${exit_code}" -ne 0 ]
        then
                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/CreateDBaaSServer.sh"
                
                set +e
                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/CheckDBaaSServerStatus.sh"
                exit_code="$?"
                set -e
                
                if [ "${exit_code}" -ne 0 ] 
                then
                        status "Could not verify DBaaS Server status"
                        exit 1
                fi
        else
                status "A database with id ${database_id} is already active, not provisioning a new one"
                
                set +e
                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/UpdateDBaaSFirewall.sh" "${database_id}" "0.0.0.0/0"
                exit_code="$?"
                set -e
                
                if [ "${exit_code}" -ne 0 ]
                then
                        status "failed to update firewall allowed ip list"
                        exit 1
                fi
        fi

        set +e
        database_id="$("${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/ObtainDatabaseID.sh")"
        exit_code="$?"
        set -e

        if [ "${exit_code}" -eq 0 ] && [ -n "${database_id}" ]
        then
                set +e
                db_payload="$("${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/ObtainDatabaseDetails.sh" "${database_id}")"
                exit_code="$?"
                set -e

                if [ "${exit_code}" -eq 0 ] && [ -n "${db_payload}" ]
                then
                        eval "${db_payload}"
                else
                        status "Error: Failed to retrieve database details." >&2
                        exit 1
                fi

                set +e
                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/ObtainDBaaSCert.sh" "${database_id}"
                exit_code="$?"
                set -e
                
                if [ "${exit_code}" -eq 0 ] 
                then
                        status "Database considered to be in a running state"
                fi

                status ""
                status "The rest of the settings for your database are as follows:"
                status "##########################################################"
                status "USERNAME:${DB_USERNAME}"
                status "PASSWORD:${DB_PASSWORD}"
                status "HOST:${DB_IDENTIFIER}"
                status "PORT:${DB_PORT}"
                status "DB NAME:${DB_NAME}"
                status "##########################################################"
        else
                status "Could not obtain database id"
                exit 1
        fi
else
        # Self-managed initialization strategy; generate randomized nonces securely
        DB_NAME="n$(/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-8 | /bin/tr '[:upper:]' '[:lower:]')n"
        DB_PASSWORD="p$(/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-8 | /bin/tr '[:upper:]' '[:lower:]')p"
        DB_USERNAME="u$(/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-8 | /bin/tr '[:upper:]' '[:lower:]')u"
        DB_IDENTIFIER="self-managed"
fi

# Process Multi-Region Clustering Mirror States
if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "0" ] 
then
        "${BUILD_HOME}/services/datastore/operations/MountDatastore.sh" "multi-region" "distributed"
        
        datastore_list="$("${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh" "multi-region" "credentials.dat")"
        if [ -n "${datastore_list}" ]
        then
                "${BUILD_HOME}/services/datastore/operations/GetFromDatastore.sh" "multi-region" "credentials.dat" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
                
                credential_target="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat"
                DB_NAME="$(/bin/grep DB_NAME "${credential_target}" | /usr/bin/awk -F'=' '{print $NF}')"
                DB_PASSWORD="$(/bin/grep DB_PASSWORD "${credential_target}" | /usr/bin/awk -F'=' '{print $NF}')"
                DB_USERNAME="$(/bin/grep DB_USERNAME "${credential_target}" | /usr/bin/awk -F'=' '{print $NF}')"
                DB_PORT="$(/bin/grep DB_PORT "${credential_target}" | /usr/bin/awk -F'=' '{print $NF}')"
                DB_IDENTIFIER="${DBaaS_PUBLIC_ENDPOINT}"
        else
                status "Credentials not found when making a multi region deployment to a non primary region"
                exit 1
        fi
fi

# Reconstruct contexts from state snapshot maps if required
snapshot_base="${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots"
if [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f "${snapshot_base}/db_credentials.dat" ]
then
        DB_USERNAME="$(/bin/grep USERNAME "${snapshot_base}/db_credentials.dat" | /usr/bin/awk -F':' '{print $NF}')"
        DB_PASSWORD="$(/bin/grep PASSWORD "${snapshot_base}/db_credentials.dat" | /usr/bin/awk -F':' '{print $NF}')"
        DB_NAME="$(/bin/grep DBNAME "${snapshot_base}/db_credentials.dat" | /usr/bin/awk -F':' '{print $NF}')"

        if [ ! -d "${snapshot_base}" ]
        then
                /bin/mkdir -p "${snapshot_base}"
        fi

        /bin/echo "USERNAME:${DB_USERNAME}" > "${snapshot_base}/db_credentials.dat.candidate"
        /bin/echo "PASSWORD:${DB_PASSWORD}" >> "${snapshot_base}/db_credentials.dat.candidate"
        /bin/echo "DBNAME:${DB_NAME}" >> "${snapshot_base}/db_credentials.dat.candidate"
fi

# Synchronize primary configuration profiles back to data tier architectures
if [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ]
then
        primary_cred_dir="${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
        /bin/echo "DB_NAME=${DB_NAME}" > "${primary_cred_dir}/credentials.dat"
        /bin/echo "DB_PASSWORD=${DB_PASSWORD}" >> "${primary_cred_dir}/credentials.dat"
        /bin/echo "DB_USERNAME=${DB_USERNAME}" >> "${primary_cred_dir}/credentials.dat"
        /bin/echo "DB_PORT=${DB_PORT}" >> "${primary_cred_dir}/credentials.dat"

        "${BUILD_HOME}/services/datastore/operations/MountDatastore.sh" "multi-region" "distributed"

        datastore_check="$("${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh" "multi-region" "credentials.dat")"
        if [ -n "${datastore_check}" ]
        then
                "${BUILD_HOME}/services/datastore/operations/DeleteFromDatastore.sh" "multi-region" "credentials.dat" "distributed"
        fi

        "${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh" "multi-region" "${primary_cred_dir}/credentials.dat" "root" "distributed" "no"
fi

# Export and persist final verified parameters to global framework context states
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_NAME=${DB_NAME}"
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_PASSWORD=${DB_PASSWORD}"
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_USERNAME=${DB_USERNAME}"
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_PORT=${DB_PORT}"
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_IDENTIFIER=${DB_IDENTIFIER}"

exit 0


