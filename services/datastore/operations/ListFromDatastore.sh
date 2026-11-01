#!/bin/sh
###################################################################################
# @file        ListFromDatastore.sh
# @brief       Context-Aware S3 Datastore Individual Object Metadata Listing Driver.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates individual file or sub-path listing tasks within 
#              managed cloud datastores. It dynamically resolves naming topologies for 
#              target S3 buckets based on specific system classifications . 
#              This inspecting operation executes strictly against your primary, first-order 
#              datastore instance, skipping replication chain loops to read metadata directly.
#
# @param       $1  [Required] The target category classification bucket type string.
# @param       $2  [Required] Name or relative pathway of the specific object/directory 
#                             to inspect. Passing "root" resets this value to empty.
# @param       $3  [Optional] Contextual tracking suffix string used for asset paths, 
#                             target sub-directories, or unique node tags.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
# @env         S3_ACCESS_KEY           Access token configurations used for fanout loops.
# @env         WEBSITE_URL             Primary base domain identifier mapping out schemas.
# @env         DNS_CHOICE              Configuration flag used to tag platform routing options.
# @env         SERVER_USER             Base tracking string used to generate local tokens.
# @env         SSL_GENERATION_SERVICE  Target backend token logic router (LETSENCRYPT/ZEROSSL).
# @env         TOKEN                   Four-character truncated identifier used to separate environments.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - GetVariableValue.sh system service wrapper infrastructure for lookup evaluations.
#              - PerformListFromDatastore.sh data removal driver selected by software parameters.
#
# @security    
#              - Avoids multi-node replication loops by anchoring targets to primary datastore contexts.
#              - Calls core text manipulation and evaluation bins explicitly from hardened paths (/bin, /usr/bin).
#
# @exit        0  Success: Target datastores were successfully listed or confirmed to exist.
# @exit        1  Failure: Missing parameters or the target datastore structure was not discovered.
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
######################################################################################
######################################################################################
#set -x
set -e

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

if [ -z "${1}" ] || [ -z "${2}" ]
then
        status "Error: 2 arguments are required and 1 optional argument"
        status "Usage: $0 <bucket_type> <file_to_list> <additional_specifier>"
        exit 1
fi

bucket_type="${1}"
file_to_list="${2}"
additional_specifier="${3}"

if [ "${file_to_list}" = "root" ]
then
        file_to_list=""
fi

S3_ACCESS_KEY="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh S3_ACCESS_KEY)"
WEBSITE_URL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_URL)"
DNS_CHOICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE)"
SSL_GENERATION_SERVICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh SSL_GENERATION_SERVICE)"
SERVER_USER="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh SERVER_USER)"
TOKEN="$(/bin/echo ${SERVER_USER} | /usr/bin/fold -w 4 | /usr/bin/head -n 1 | /usr/bin/tr '[:upper:]' '[:lower:]')"

case "${bucket_type}" in
        "ssl")
                if [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
                then
                        service_token="lets"
                elif [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
                then
                        service_token="zero" 
                fi
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
                active_bucket="${active_bucket}-${DNS_CHOICE}-${service_token}-ssl"
                ;;
        "auth-ssl")
                WEBSITE_URL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_SERVER_URL)"
                DNS_CHOICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_DNS_CHOICE)"
                if [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
                then
                        service_token="lets"
                elif [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
                then
                        service_token="zero"
                fi
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
                active_bucket="${active_bucket}-${DNS_CHOICE}-${service_token}-ssl"
                ;;
        "auth-ssl-1")
                WEBSITE_URL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_SERVER_URL)"
                WEBSITE_URL="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/[^.]*/auth/')"
                DNS_CHOICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_DNS_CHOICE)"
                if [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ]
                then
                        service_token="lets"
                elif [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ]
                then
                        service_token="zero"
                fi
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
                active_bucket="${active_bucket}-${DNS_CHOICE}-${service_token}-ssl"
                ;;
        "multi-region")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-multi-region"
                ;;
        "webroot-sync"|"config-sync")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-${bucket_type}-tunnel$(/bin/echo ${additional_specifier} | /bin/sed 's:/:-:g')"
                ;;
        "config"|"auth-config")
                if [ "${bucket_type}" = "auth-config" ]
                then
                        WEBSITE_URL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_SERVER_URL)"
                fi
                active_bucket="$(/bin/echo "${WEBSITE_URL}"-config | /bin/sed 's/\./-/g')-${TOKEN}"
                ;;
        "asset")
                active_bucket="$(/bin/echo "${WEBSITE_URL}-assets-${additional_specifier}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g')"
                ;;
        "backup-web")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-${additional_specifier}"
                ;;
        "backup-db")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-db-${additional_specifier}"
                ;;
        "scaling")
                active_bucket="$(/bin/echo ${additional_specifier} | /bin/sed 's/\./-/g')"
                ;;
        "firewall-auth-laptop-ips"|"whitelist-auth-laptop-ips"|"firewall-emailed-links"|"whitelist-emailed-links"|"basic-auth-credentials")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-${bucket_type}"
                ;;
        "wire-guard")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-wireguard"
                ;;
        "wire-guard-emails")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-wireguard-emails"
                ;;
        "wire-guard-emailed-links")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-wireguard-emailed-links"
                ;;
        "auth")
                active_bucket="authip-adt-allowed-${additional_specifier}"
                ;;
        "dbaas"|"snap")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
                active_bucket="${active_bucket}-${DNS_CHOICE}-${bucket_type}"
                ;;
        "ad-hoc")
                active_bucket="${additional_specifier}"
                ;;
        *)
                active_bucket="${bucket_type}"
                ;;
esac

datastore_tool="$(/bin/grep "^DATASTORETOOL:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $2}')"

${BUILD_HOME}/services/datastore/operations/${datastore_tool}/PerformListFromDatastore.sh ${active_bucket}/${file_to_list}
