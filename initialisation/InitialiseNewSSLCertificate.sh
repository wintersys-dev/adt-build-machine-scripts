#!/bin/sh
###################################################################################
# Author: Peter Winter
# Date  : 12/07/2016
# Description : This script will generate an SSL Certificate if one is needed
# A new SSL certificate in two cases, a SSL certificate does not already exist
# or the SSL certificate that does exists is considered close to expiring
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
# along with The Agile Deployment Toolkit.  If not, see <http://www.gnu.org/licenses/>.
##################################################################################
##################################################################################
#set -x

status () {
        /bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
        script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
        /bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

auth="${1}"

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
if ( [ "`/usr/bin/pwd`" != "${BUILD_HOME}" ] )
then
        cd ${BUILD_HOME}
fi

if ( [ "${auth}" = "wire-guard" ] )
then
        AUTHENTICATOR_TYPE="`${BUILD_HOME}/helpers/GetVariableValue.sh AUTHENTICATOR_TYPE`"
        if ( [ "${AUTHENTICATOR_TYPE}" != "wire-guard" ] )
        then
                exit
        fi
fi

SSL_GENERATION_METHOD="`${BUILD_HOME}/helpers/GetVariableValue.sh SSL_GENERATION_METHOD`"
SSL_GENERATION_SERVICE="`${BUILD_HOME}/helpers/GetVariableValue.sh SSL_GENERATION_SERVICE`"
CLOUDHOST="`${BUILD_HOME}/helpers/GetVariableValue.sh CLOUDHOST`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/GetVariableValue.sh BUILD_IDENTIFIER`"
DNS_CHOICE="`${BUILD_HOME}/helpers/GetVariableValue.sh DNS_CHOICE`"
datastore_identifier="ssl"
config_datastore_identifier="config"


if ( [ "${website_url}" != "" ] && [ "${website_url}" != "none" ] )
then
        WEBSITE_URL="${website_url}"
else
        WEBSITE_URL="`${BUILD_HOME}/helpers/GetVariableValue.sh WEBSITE_URL`"
fi

if ( [ "${AUTHENTICATOR_TYPE}" = "wire-guard" ] && [ "${auth}" = "no" ] )
then
        datastore_identifier="wireguard-rp-ssl"
        WEBSITE_URL="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/www8/www/g'`"
fi

if ( [ "${auth}" = "yes" ] )
then
        datastore_identifier="auth-ssl"
        config_datastore_identifier="auth-config"
        WEBSITE_URL="`${BUILD_HOME}/helpers/GetVariableValue.sh AUTH_SERVER_URL`"
        DNS_USERNAME="`${BUILD_HOME}/helpers/GetVariableValue.sh AUTH_DNS_USERNAME`"
        DNS_SECURITY_KEY="`${BUILD_HOME}/helpers/GetVariableValue.sh AUTH_DNS_SECURITY_KEY`"
        DNS_CHOICE="`${BUILD_HOME}/helpers/GetVariableValue.sh AUTH_DNS_CHOICE`"
fi

generate_new="0"

if ( [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ] )
then
        service_token="lets"
elif ( [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ] )
then
        service_token="zero"
fi

${BUILD_HOME}/services/datastore/operations/MountDatastore.sh "${datastore_identifier}" "local" 

if ( ( [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "${datastore_identifier}" "fullchain.pem"`" != "" ] && [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "${datastore_identifier}" "privkey.pem"`" != "" ] ) || ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem ] && [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem ] ) )
then
        if ( [ ! -d ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL} ] )
        then
                /bin/mkdir -p ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}
        fi

        #Override whatever is on the filesystem (if anything) with what is in the datastore
        if ( [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "${datastore_identifier}" "fullchain.pem"`" != "" ] && [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "${datastore_identifier}" "privkey.pem"`" != "" ] ) 
        then
                status "Found existing SSL certificates in the datastore for website url ${WEBSITE_URL} trying to use those to save time and reissuance"
                ${BUILD_HOME}/services/datastore/operations/GetFromDatastore.sh "${datastore_identifier}" "fullchain.pem" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}"
                ${BUILD_HOME}/services/datastore/operations/GetFromDatastore.sh "${datastore_identifier}" "privkey.pem" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}"
        fi

        status "Checking that current certificate is not expired"
        if ( [ -s ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem ] && [ -s ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem ] )
        then
                if ( [ "`/usr/bin/openssl x509 -checkend 604800 -noout -in ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem | /bin/grep 'Certificate will expire'`" != "" ] )
                then
                        status "Taking action, existing certificate is expired (has 7 days or less left on its validity)"
                        /bin/mv ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem.$$.old
                        /bin/mv ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem.$$.old
                        generate_new="1"
                else
                        status "Existing certificate found to be valid, no action necessary, reusing it"
                fi
        else
                status "Valid certificate not found will attempt to generate a new one"
                generate_new="1"
        fi
fi

if ( [ "${website_url}" = "none" ] || ( [ ! -s ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem ] || [ ! -s ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem ] ) )
then
        generate_new="1"
elif ( [ -s ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem ] && [ -s ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem ] )
then
        ${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "${datastore_identifier}" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem" "root" "local" "no" 
        ${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "${datastore_identifier}" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem" "root" "local" "no" 
        ${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "${config_datastore_identifier}" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem" "ssl/${WEBSITE_URL}" "local" "no"
        ${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "${config_datastore_identifier}" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem" "ssl/${WEBSITE_URL}" "local" "no"
fi

if ( [ "${generate_new}" = "1" ] )
then
        #IP has been added to the DNS provider and now we have to set up the SSL certificate for this webserver

        if ( [ "${SSL_GENERATION_METHOD}" = "AUTOMATIC" ] )
        then
                if ( [ "${SSL_GENERATION_SERVICE}" = "LETSENCRYPT" ] )
                then
                        if ( [ "`/bin/grep "^SSLCERTCLIENT:lego" ${BUILD_HOME}/configuration/software.dat`" = "" ] )
                        then
                                if ( [ "`/bin/grep "^SSLCERTCLIENT:" ${BUILD_HOME}/configuration/software.dat`" != "" ] )
                                then
                                        /bin/sed -i 's/SSLCERTCLIENT:.*/SSLCERTCLIENT:lego:binary/g' ${BUILD_HOME}/configuration/software.dat
                                else
                                        /bin/echo "SSLCERTCLIENT:lego:binary" >> ${BUILD_HOME}/configuration/software.dat
                                fi
                        fi

                        ${BUILD_HOME}/services/security/ssl/lego/ProvisionAndArrangeSSLCertificate.sh "${WEBSITE_URL}" "${auth}"
                fi

                if ( [ "${SSL_GENERATION_SERVICE}" = "ZEROSSL" ] )
                then
                        if ( [ "`/bin/grep "^SSLCERTCLIENT:acme" ${BUILD_HOME}/configuration/software.dat`" = "" ] )
                        then
                                if ( [ "`/bin/grep "^SSLCERTCLIENT:" ${BUILD_HOME}/configuration/software.dat`" != "" ] )
                                then
                                        /bin/sed -i 's/SSLCERTCLIENT:.*/SSLCERTCLIENT:acme:github.com/g' ${BUILD_HOME}/configuration/software.dat
                                else
                                        /bin/echo "SSLCERTCLIENT:acme:github.com" >> ${BUILD_HOME}/configuration/software.dat
                                fi
                        fi

                        ${BUILD_HOME}/services/security/ssl/acme/ProvisionAndArrangeSSLCertificate.sh "${WEBSITE_URL}" "${auth}"
                        /bin/cat ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem >> ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem
                fi

                if ( [ "${SSL_GENERATION_METHOD}" = "MANUAL" ] )
                then
                        ${BUILD_HOME}/services/security/ssl/manual/ProvisionAndArrangeSSLCertificate.sh ${WEBSITE_URL} ${auth}
                fi
        fi

        if ( [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify ] )
        then
                /bin/mkdir ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify
        fi

        if ( [ -s ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem ] && [ -s ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem ] )
        then
                if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/privkey.pem ] )
                then
                        /bin/rm ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/privkey.pem 
                fi

                if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/fullchain.pem ] )
                then
                        /bin/rm ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/fullchain.pem 
                fi

                ${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "${config_datastore_identifier}" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem" "ssl/${WEBSITE_URL}" "local" "no"
                ${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "${config_datastore_identifier}" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem" "ssl/${WEBSITE_URL}" "local" "no"
                ${BUILD_HOME}/services/datastore/operations/GetFromDatastore.sh "${config_datastore_identifier}" "ssl/${WEBSITE_URL}/privkey.pem" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify"
                ${BUILD_HOME}/services/datastore/operations/GetFromDatastore.sh "${config_datastore_identifier}" "ssl/${WEBSITE_URL}/fullchain.pem" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify"

                if ( [ "`/usr/bin/diff ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/privkey.pem ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem`" != "" ] )
                then
                        status "SSL Certificate Verification failed for ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem"
                        /bin/touch /tmp/END_IT_ALL

                fi

                if ( [ "`/usr/bin/diff ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/fullchain.pem ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem`" != "" ] )
                then
                        status "SSL Certificate Verification failed for ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem"
                        /bin/touch /tmp/END_IT_ALL
                fi

                if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/privkey.pem ] )
                then
                        /bin/rm ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/privkey.pem
                fi

                if ( [ ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/fullchain.pem ] )
                then
                        /bin/rm ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/verify/fullchain.pem
                fi

                status "SSL Certificates successfully validated"
                status "Putting SSL Certificates into the datastore"

                ${BUILD_HOME}/services/datastore/operations/MoveDatastoreObject.sh "${datastore_identifier}" "fullchain.pem" "fullchain.pem.$$.old" "local"
                ${BUILD_HOME}/services/datastore/operations/MoveDatastoreObject.sh "${datastore_identifier}" "privkey.pem" "privkey.pem.$$.old" "local"
                ${BUILD_HOME}/services/datastore/operations/DeleteFromDatastore.sh "${datastore_identifier}" "fullchain.pem" "local"
                ${BUILD_HOME}/services/datastore/operations/DeleteFromDatastore.sh "${datastore_identifier}" "privkey.pem" "local"
                ${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "${datastore_identifier}" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/fullchain.pem" "root" "local" "no"
                ${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "${datastore_identifier}" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/ssl/${DNS_CHOICE}/${service_token}/${WEBSITE_URL}/privkey.pem" "root" "local" "no"

                if ( [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "${datastore_identifier}" "fullchain.pem"`" = "" ] || [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "${datastore_identifier}" "privkey.pem"`" = "" ] )
                then
                        ${BUILD_HOME}/services/datastore/operations/MoveDatastoreObject.sh "${datastore_identifier}" "fullchain.pem.$$.old" "fullchain.pem"
                        ${BUILD_HOME}/services/datastore/operations/MoveDatastoreObject.sh "${datastore_identifier}" "privkey.pem.$$.old" "privkey.pem"
                else
                        ${BUILD_HOME}/services/email/SendEmail.sh "NEW SSL CERTIFICATE PUT IN DATASTORE" "SSL Certificate successfully provisioned/generated" "INFO"
                fi
        else
                ${BUILD_HOME}/services/email/SendEmail.sh "SSL CERTIFICATE NOT SUCCESSFULLY GENERATED" "SSL Certificate not successfully provisioned/generated" "ERROR"
                status "SSL Certificate not successfully provisioned/generated"
                /bin/touch /tmp/END_IT_ALL
        fi
fi

if ( [ -f /root/HARDCORE ] && [ "${website_url}" = "none" ] )
then
        /bin/rm /root/HARDCORE
fi
