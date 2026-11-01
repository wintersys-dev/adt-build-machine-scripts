#!/bin/sh
###################################################################################
# @file        UploadFile.sh
# @brief       Context-Aware S3 Datastore Content Uploading & Staging Utility.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates uploading individual files or asset directories 
#              to managed cloud datastores. It dynamically constructs naming 
#              topologies for target S3 buckets based on specific system profiles. It passes the 
#              payload to an underlying script execution engine with an optional 
#              post-upload deletion flag, executing either against a standalone primary 
#              endpoint ("local") or propagating sequentially across multi-node 
#              distributed regional clusters ("distributed").
#
# @param       $1  [Required] The target category classification bucket type string.
# @param       $2  [Required] Absolute or relative local pathway of the file to upload.
# @param       $3  [Required] Target destination folder path within the bucket ("root" maps to base).
# @param       $4  [Required] Topology routine selection ("local" or "distributed").
# @param       $5  [Required] Switch flag (true/false or 1/0) to purge local source post-upload.
# @param       $6  [Optional] Contextual tracking suffix string for paths or node tags.
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
#              - PerformPutToDatastore.sh data loading engine driver managing storage interactions.
#
# @security    
#              - Processes isolated S3_ACCESS_KEY credential loops securely during multi-region execution.
#              - Employs post-upload cleanup routing toggles ($5) to mitigate local file footprint leakage.
#              - restrains parameter processing tools strictly to validated target paths (/bin, /usr/bin).
#
# @exit        0  Success: Local payloads were successfully staged to the cloud storage target.
# @exit        1  Failure: Missing parameters or an error code returned from the backend driver.
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

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ] || [ -z "${5}" ]
then
        status "Error: 5 arguments are required and 1 optional argument"
        status "Usage: $0 <bucket_type> <file_to_put> <place_to_put> <mode> <delete> <additional_specifier>"
        exit 1
fi

bucket_type="${1}"
file_to_put="${2}"
place_to_put="${3}"
mode="${4}"
delete="${5}"
additional_specifier="${6}"

S3_ACCESS_KEY="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh S3_ACCESS_KEY)"
WEBSITE_URL="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_URL)"
DNS_CHOICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE)"
SSL_GENERATION_SERVICE="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh SSL_GENERATION_SERVICE)"
SERVER_USER="$(${BUILD_HOME}/helpers/services/GetVariableValue.sh SERVER_USER)"
TOKEN="$(/bin/echo ${SERVER_USER} | /usr/bin/fold -w 4 | /usr/bin/head -n 1 | /usr/bin/tr '[:upper:]' '[:lower:]')"

if [ "${place_to_put}" = "root" ]
then
        place_to_put=""
fi

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
        "backup-web"|"scaling")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-${additional_specifier}"
                ;;
        "backup-db")
                active_bucket="$(/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g')-db-${additional_specifier}"
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

no_tokens="$(/bin/echo "${S3_ACCESS_KEY}" | /usr/bin/fgrep -o '|' | /usr/bin/wc -l)"
no_tokens="$(/usr/bin/expr ${no_tokens} + 1)"

count="1"

if [ "${mode}" = "local" ]
then
        ${BUILD_HOME}/services/datastore/operations/${datastore_tool}/PerformPutToDatastore.sh ${file_to_put} ${active_bucket}/${place_to_put} ${delete} ${count}
elif [ "${mode}" = "distributed" ]
then
        while [ "${count}" -le "${no_tokens}" ]
        do
                ${BUILD_HOME}/services/datastore/operations/${datastore_tool}/PerformPutToDatastore.sh ${file_to_put} ${active_bucket}/${place_to_put} ${delete} ${count}
                count="$(/usr/bin/expr ${count} + 1)"
done
fi
