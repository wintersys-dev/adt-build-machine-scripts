#!/bin/sh
#: Name:        ProvisionDBaaS.sh
#: Purpose:     Manages cloud DBaaS provisioning, credentials, and multi-region synchronization.
#: Author:      Peter Winter
#: Date:        15/11/2026
#: Version:     1.0
#:
#: Usage:       ProvisionDBaaS.sh
#:              ProvisionDBaaS.sh [-h|--help]
#:
#: Parameters:
#:   None       Reads database, cloudhost, and regional variables via GetVariableValue.sh.
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - GetVariableValue.sh
#:   - SetVariableValue.sh
#:   - ${BUILD_HOME}/configuration/software.dat
#:   - ${BUILD_HOME}/services/dbaas/<cloudhost>/<tool>/<engine>/*
#:   - ${BUILD_HOME}/services/datastore/operations/*
#:   - External binaries: cat, echo, grep, cut, awk, tr, mkdir, openssl
#:
#: Exit Codes:
#:   0          Target database engine and context configured and exported cleanly
#:   1          Mismatched environment profiles, failed validation, or execution error
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

# Retrieve database, provider, and multi-region topology variables from active context
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
VPC_IP_RANGE="$("${BUILD_HOME}/helpers/services/GetVariableValue.sh" VPC_IP_RANGE)"

# Verify that the core software configuration file exists and is readable
software_file="${BUILD_HOME}/configuration/software.dat"
if [ ! -f "${software_file}" ] || [ ! -r "${software_file}" ]
then
        status "Error: Cannot read software configuration file at ${software_file}"
        exit 1
fi

# Extract the active orchestration tool (cli or api) from software.dat
orchestration_tool="$(/usr/bin/awk -F':' '/^ORCHESTRATION_TOOL:/ {print $NF}' "${software_file}")"

# Prevent managed DBaaS provisioning when running in DEVELOPMENT mode
if [ "${DEPLOYMENT_MODE}" = "DEVELOPMENT" ] && [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ]
then
        status "You are attempting to provision a managed database in development mode, this isn't supported you need to redeploy in production mode"
        exit 1
fi

# Orchestrate cloud-managed DBaaS creation or reuse on single-region / primary builds
if [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ] && { [ "${MULTI_REGION}" = "0" ] || { [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ]; }; }
then
        # Extract the lowercase engine slug (e.g. mysql, postgres) from the installation profile
        database_type_lower="$(/bin/echo "${DATABASE_DBaaS_INSTALLATION_TYPE}" | /usr/bin/awk -F':' '{print $1}' | /bin/tr '[:upper:]' '[:lower:]')"

        # Verify that the requested DBaaS engine and version are supported by the provider
        set +e
        "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/verify_selected_engine.sh"
        exit_code="$?"
        set -e

        if [ "${exit_code}" -ne 0 ]
        then
                status "Database Engine not successfully verified"
                exit 1
        fi

        # Check if a matching managed database cluster already exists
        set +e
        database_id="$("${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/obtain_dbaas_id.sh")"
        exit_code="$?"
        set -e

        if [ "${exit_code}" -ne 0 ]
        then
                # Provision a new managed DBaaS cluster and wait for it to become active
                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/create_dbaas_server.sh"

                set +e
                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/check_dbaas_service_status.sh"
                exit_code="$?"
                set -e

                if [ "${exit_code}" -ne 0 ]
                then
                        status "Could not verify DBaaS Server status"
                        exit 1
                fi
        else
                # Reuse the existing active DBaaS cluster and temporarily open access for build setup
                status "A database with id ${database_id} is already active, not provisioning a new one"

                set +e
                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/update_dbaas_firewall.sh" "${database_id}" "${VPC_IP_RANGE}"
                exit_code="$?"
                set -e

                if [ "${exit_code}" -ne 0 ]
                then
                        status "failed to update firewall allowed ip list"
                        exit 1
                fi
        fi

        # Re-fetch the verified cluster ID and extract connection credentials and SSL certificate
        set +e
        database_id="$("${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/obtain_dbaas_id.sh")"
        exit_code="$?"
        set -e

        if [ "${exit_code}" -eq 0 ] && [ -n "${database_id}" ]
        then
                set +e
                db_payload="$("${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/obtain_dbaas_details.sh" "${database_id}")"
                exit_code="$?"
                set -e

                if [ "${exit_code}" -eq 0 ] && [ -n "${db_payload}" ]
                then
                        eval "${db_payload}"
                else
                        status "Error: Failed to retrieve database details." 
                        exit 1
                fi

                set +e
                "${BUILD_HOME}/services/dbaas/${CLOUDHOST}/${orchestration_tool}/${database_type_lower}/obtain_dbaas_cert.sh" "${database_id}"
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
        # Self-managed database strategy: generate randomized alphanumeric credentials via OpenSSL
        DB_NAME="n$(/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-8 | /bin/tr '[:upper:]' '[:lower:]')n"
        DB_PASSWORD="p$(/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-8 | /bin/tr '[:upper:]' '[:lower:]')p"
        DB_USERNAME="u$(/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-8 | /bin/tr '[:upper:]' '[:lower:]')u"
        DB_IDENTIFIER="self-managed"
fi

# On secondary multi-region builds, pull shared database credentials from the distributed datastore
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

# Restore saved database credentials when rebuilding from a whole-machine snapshot
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

# On primary multi-region builds, publish database credentials to the distributed datastore
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

# Persist final resolved database parameters into the global toolkit configuration
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_NAME=${DB_NAME}"
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_PASSWORD=${DB_PASSWORD}"
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_USERNAME=${DB_USERNAME}"
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_PORT=${DB_PORT}"
"${BUILD_HOME}/helpers/services/SetVariableValue.sh" "DB_IDENTIFIER=${DB_IDENTIFIER}"

exit 0



