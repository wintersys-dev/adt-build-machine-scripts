#!/bin/sh
###################################################################################
# @file        GetFromDatastore.sh
# @brief       Context-Aware S3 Datastore Object Retrieval & Fetching Utility.
# @author      Peter Winter
# @date        09/04/2021
# @version     1.0
#
# @details     This script automates individual file retrieval tasks from managed cloud 
#              datastores. It dynamically resolves naming topologies for target S3 
#              buckets based on specific system classifications. Unlike purging utilities, 
#              this fetching operation executes strictly against your primary first-order 
#              datastore instance, skipping replication loops.
#
# @param       $1  [Required] The target category classification bucket type string.
# @param       $2  [Required] Name or relative pathway of the specific cloud object to fetch.
# @param       $3  [Required] Local directory path or target file name destination.
# @param       $4  [Optional] Contextual tracking suffix string for paths or node tags.
#
# @env         BUILD_HOME              Sourced application root tracking pathway string.
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
#              - PerformGetFromDatastore.sh object retrieval engine driver matching the active tool setup.
#
# @security    
#              - Avoids multi-node replication loops by anchoring targets to primary datastore contexts.
#              - Standardises the destination parameter to the local directory (.) if left blank.
#              - Isolates path execution variables by relying on hardened system paths (/bin, /usr/bin).
#
# @exit        0  Success: The specified cloud object was retrieved and stored locally.
# @exit        1  Failure: Missing arguments or error status returned by the retrieval driver.
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
#########################################################################################
#########################################################################################
#set -x
set -e

status () {
        ${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
}

BUILD_HOME="$(/bin/cat /home/buildhome.dat)"

if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]
then
        status "Error: 3 arguments are required and 1 optional argument"
        status "Usage: $0 <bucket_type> <file_to_get> <destination> <additional_specifier>"
        exit 1
fi

bucket_type="${1}"
file_to_get="${2}"
destination="${3}"
additional_specifier="${4}"

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

if [ -z "${destination}" ]
then
        destination="."
fi

datastore_tool="$(/bin/grep "^DATASTORETOOL:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $2}')"

${BUILD_HOME}/services/datastore/operations/${datastore_tool}/PerformGetFromDatastore.sh ${active_bucket}/${file_to_get} ${destination}



