#!/bin/sh
#########################################################################################
# Tool/Script: Context-Aware S3 Datastore Object Retrieval & Fetching Utility
# Author:      Peter Winter
# Date :       9/4/2021
# Suite:       The Agile Deployment Toolkit
# 
# Description: This script automates individual file retrieval tasks from managed cloud 
#              datastores. It dynamically resolves naming topologies for target S3 
#              buckets based on specific system classifications. 
#              Unlike purging utilities, this fetching operation executes strictly against 
#              your primary first-order datastore instance, skipping replication loops.
#
# Arguments:
#              $1 - <bucket_type>            : Target category classification. 
#              $2 - <file_to_get>            : Name or relative pathway of the specific cloud object to fetch.
#              $3 - <destination>            : Local directory path or target file name destination.
#              $4 - [additional_specifier]   : Optional tracking suffix used for asset paths, directory 
#                                              roots, or unique runtime token suffixes.
#
# Environmental Dependencies:
#              - /home/buildhome.dat containing valid application root pathway tracking string.
#              - Toolkit helpers: GetVariableValue.sh script infrastructure for variable evaluations.
#              - Environment registers: WEBSITE_URL, DNS_CHOICE, SERVER_USER, 
#                                       SSL_GENERATION_SERVICE configuration states.
#########################################################################################
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
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}


if ( [ "${1}" = "" ] || [ "${2}" = "" ] || [ "${3}" = "" ] )
then
        status "Error: 3 arguments are required and 1 optional argument"
        status "Usage: $0 <bucket_type> <file_to_get> <destination> <additional_specifier>"
        exit 1
fi

bucket_type="${1}"
file_to_get="${2}"
destination="${3}"
additional_specifier="${4}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_URL`"
DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE`"
SSL_GENERATION_SERVICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SSL_GENERATION_SERVICE`"
SERVER_USER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh SERVER_USER`"
TOKEN="`/bin/echo ${SERVER_USER} | /usr/bin/fold -w 4 | /usr/bin/head -n 1 | /usr/bin/tr '[:upper:]' '[:lower:]'`"

if ( [ "${bucket_type}" = "ssl" ] )
then
        if ( [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ] )
        then
                service_token="lets"
        elif ( [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ] )
        then
                service_token="zero" 
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-${DNS_CHOICE}-${service_token}-ssl"
elif ( [ "${bucket_type}" = "auth-ssl" ] )
then
        WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_SERVER_URL`"
        DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_DNS_CHOICE`"
        if ( [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ] )
        then
                service_token="lets"
        elif ( [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ] )
        then
                service_token="zero"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-${DNS_CHOICE}-${service_token}-ssl"
elif ( [ "${bucket_type}" = "auth-ssl-1" ] )
then
        WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_SERVER_URL`"
        WEBSITE_URL="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/[^.]*/auth/'`"
        DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_DNS_CHOICE`"
        
        if ( [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ] )
        then
                service_token="lets"
        elif ( [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ] )
        then
                service_token="zero"
        fi
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-${DNS_CHOICE}-${service_token}-ssl"
elif ( [ "${bucket_type}" = "multi-region" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-multi-region"
elif ( [ "${bucket_type}" = "webroot-sync" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-webroot-sync-tunnel`/bin/echo ${additional_specifier} | /bin/sed 's:/:-:g'`"
elif ( [ "${bucket_type}" = "config-sync" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-config-sync-tunnel`/bin/echo ${additional_specifier} | /bin/sed 's:/:-:g'`"
elif ( [ "${bucket_type}" = "config" ] )
then
        active_bucket="`/bin/echo "${WEBSITE_URL}"-config | /bin/sed 's/\./-/g'`-${TOKEN}"
elif ( [ "${bucket_type}" = "auth-config" ] )
then
        WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh AUTH_SERVER_URL`"
        active_bucket="`/bin/echo "${WEBSITE_URL}"-config | /bin/sed 's/\./-/g'`-${TOKEN}"
elif ( [ "${bucket_type}" = "asset" ] )
then
        active_bucket="`/bin/echo "${WEBSITE_URL}-assets-${additional_specifier}" | /bin/sed -e 's/\./-/g' -e 's;/;-;g' -e 's/--/-/g'`"
elif ( [ "${bucket_type}" = "scaling" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-${additional_specifier}"
elif ( [ "${bucket_type}" = "firewall-auth-laptop-ips" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-firewall-auth-laptop-ips"
elif ( [ "${bucket_type}" = "firewall-emailed-links" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-firewall-emailed-links"
elif ( [ "${bucket_type}" = "whitelist-auth-laptop-ips" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-whitelist-auth-laptop-ips"
elif ( [ "${bucket_type}" = "whitelist-emailed-links" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-whitelist-emailed-links"
elif ( [ "${bucket_type}" = "basic-auth-credentials" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-basic-auth-credentials"
elif ( [ "${bucket_type}" = "wire-guard" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-wireguard"
elif ( [ "${bucket_type}" = "wire-guard-emails" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-wireguard-emails"
elif ( [ "${bucket_type}" = "wire-guard-emailed-links" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-wireguard-emailed-links"
elif ( [ "${bucket_type}" = "backup-web" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-${additional_specifier}"
elif ( [ "${bucket_type}" = "backup-db" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`-db-${additional_specifier}"
elif ( [ "${bucket_type}" = "auth" ] )
then
        active_bucket="authip-adt-allowed-${additional_specifier}"
elif ( [ "${bucket_type}" = "dbaas" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-${DNS_CHOICE}-dbaas"
elif ( [ "${bucket_type}" = "snap" ] )
then
        active_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
        active_bucket="${active_bucket}-${DNS_CHOICE}-snap"
elif ( [ "${bucket_type}" = "ad-hoc" ] )
then
        active_bucket="1$$agile"
else 
        active_bucket="${bucket_type}"
fi

if ( [ "${destination}" = "" ] )
then
        destination="."
fi

datastore_tool="`/bin/grep "^DATASTORETOOL:*" ${BUILD_HOME}/configuration/software.dat | /usr/bin/awk -F':' '{print $2}'`"

${BUILD_HOME}/services/datastore/operations/${datastore_tool}/PerformGetFromDatastore.sh ${active_bucket}/${file_to_get} ${destination}

if ( [ "$?" != "0" ] )
then
        status "PerformGetFromDatastore.sh returned an error code"
        exit 1
fi

