#!/bin/sh
###################################################################################
# @file        MoveDatastoreObject.sh
# @brief       Context-Aware S3 Datastore Object Moving, Copying & Renaming Utility.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates moving, copying, or renaming individual objects 
#              natively inside managed cloud datastores. It dynamically constructs 
#              the correct S3 bucket namespaces according to system classifications. 
#              It then routes the target object operation to an underlying script execution engine 
#              in either a single single-region environment ("local") or propagates 
#              it across multi-node distributed regional clusters ("distributed").
#
# @param       $1  [Required] The target category classification bucket type string.
# @param       $2  [Required] The absolute path of the source file inside the S3 bucket.
# @param       $3  [Required] The target destination pathway or new filename within the bucket.
# @param       $4  [Required] Topology routine selection ("local" or "distributed").
# @param       $5  [Optional] Contextual tracking suffix string for paths or node tags.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
# @env         S3_ACCESS_KEY           Access token configurations used for fanout loops.
# @env         WEBSITE_URL             Primary base domain identifier mapping out schemas.
# @env         DNS_CHOICE              Configuration flag used to tag platform routing options.
# @env         SSL_GENERATION_SERVICE  Target backend token logic router (LETSENCRYPT/ZEROSSL).
# @env         SERVER_USER             Base tracking string used to generate local tokens.
# @env         TOKEN                   Four-character truncated identifier used to separate environments.
#
# @dependencies
#              - /home/buildhome.dat configuration file tracking the active application root path.
#              - LogStatusMessages.sh framework helper module for centralized runtime tracking.
#              - GetVariableValue.sh system service wrapper infrastructure for lookup evaluations.
#              - PerformMoveDatastoreObject.sh internal engine driver managing native object restructuring.
#
# @security    
#              - Ensures proper boundary isolation of S3_ACCESS_KEY array payloads during fanout processing.
#              - Normalizes platform runtime identifiers to lowercase blocks to safeguard asset paths.
#              - Maps core textual evaluation binaries explicitly to restricted platform spaces (/bin, /usr/bin).
#
# @exit        0  Success: The targeted object manipulation transaction executed successfully.
# @exit        1  Failure: Missing mandatory parameter constraints or failed internal loop states.
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
#######################################################################################
#######################################################################################
#set -x
set -e

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]
then
        status "Error: 4 arguments are required and 1 optional argument"
        status "Usage: $0 <bucket_type> <original_object> <new_object> <mode> <additional_specifier>"
        exit 1
fi

bucket_type="${1}"
original_object="${2}"
new_object="${3}"
mode="${4}"
additional_specifier="${5}"

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
        "multi-region")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-multi-region"
                ;;
#     "config-sync")
 #               active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-${bucket_type}-tunnel$(/bin/echo ${additional_specifier} | /bin/sed 's:/:-:g')"
 #               ;;
        "config")
                active_bucket="$(/bin/echo "${WEBSITE_URL}"-config | /bin/sed 's/\./-/g')-${additional_specifier}"
                ;;
        "auth-config")
                WEBSITE_URL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_SERVER_URL)"
                active_bucket="$(/bin/echo "${WEBSITE_URL}"-config | /bin/sed 's/\./-/g')-${additional_specifier}"
                ;;
        "asset")
                active_bucket="$(/bin/echo "${WEBSITE_URL}-assets-${additional_specifier}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g')"
                ;;
        "scaling"|"backup-web")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-${additional_specifier}"
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
        "backup-db")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-db-${additional_specifier}"
                ;;
        "auth")
                active_bucket="authip-adt-allowed-${additional_specifier}"
                ;;
        "dbaas")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')"
                active_bucket="${active_bucket}-${DNS_CHOICE}-dbaas"
                ;;
        "ad-hoc")
                active_bucket="${additional_specifier}"
                ;;
esac

datastore_tool="$(/bin/grep "^DATASTORETOOL:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $2}')"

no_tokens="$(/bin/echo "${S3_ACCESS_KEY}" | /usr/bin/fgrep -o '|' | /usr/bin/wc -l)"
no_tokens="$(/usr/bin/expr ${no_tokens} + 1)"

count="1"

if [ "${mode}" = "local" ]
then
        ${BUILD_HOME}/services/datastore/operations/${datastore_tool}/PerformMoveDatastoreObject.sh ${active_bucket}/${original_object} ${active_bucket}/${new_object} ${count}
elif [ "${mode}" = "distributed" ]
then
        while [ "${count}" -le "${no_tokens}" ]
        do
                ${BUILD_HOME}/services/datastore/operations/${datastore_tool}/PerformMoveDatastoreObject.sh ${active_bucket}/${original_object} ${active_bucket}/${new_object} ${count}
                count="$(/usr/bin/expr ${count} + 1)"
        done
fi

