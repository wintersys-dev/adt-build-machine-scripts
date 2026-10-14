#!/bin/sh
########################################################################################
# Author: Peter Winter
# Date  : 12/07/2021
# Description : This is a script which enables you to shortcut the deployment of DBaaS systems
# when using the hardcore or expedited build. You do it by setting the DATABASE_DBaaS_INSTALLATION_TYPE
# variable in the way described for each provider. When set as described for your provider,
# when you make the deployment this script will try and spin up a DBaaS system and use that. 
# Alternative you can pre-provision your DBaaS database using the GUI system if you don't want to wait
# for it to provision whilst the script is running (which for some providers can take a bit of time)
########################################################################################
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
#########################################################################################
#########################################################################################
#set -x

status () {
	/bin/echo "${1}" | /usr/bin/tee /dev/fd/3 2>/dev/null
	script_name="`/bin/echo ${0} | /usr/bin/awk -F'/' '{print $NF}'`"
	/bin/echo "${script_name}: ${1}" | /usr/bin/tee -a /dev/fd/4 2>/dev/null
}

BUILD_HOME="`/bin/cat /home/buildhome.dat`"
DATABASE_DBaaS_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_DBaaS_INSTALLATION_TYPE`"
CLOUDHOST="`${BUILD_HOME}/helpers/services/GetVariableValue.sh CLOUDHOST`"
DATABASE_INSTALLATION_TYPE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DATABASE_INSTALLATION_TYPE`"
DB_INSTALL_MODE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DB_INSTALL_MODE`"
VPC_IP_RANGE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh VPC_IP_RANGE`"
DB_PORT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DB_PORT`"
BUILD_IDENTIFIER="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_IDENTIFIER`"
REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh REGION`"
BUILD_FROM_SNAPSHOT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh BUILD_FROM_SNAPSHOT`"
MULTI_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh MULTI_REGION`"
PRIMARY_REGION="`${BUILD_HOME}/helpers/services/GetVariableValue.sh PRIMARY_REGION`"
DBaaS_PUBLIC_ENDPOINT="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DBaaS_PUBLIC_ENDPOINT`"
DNS_CHOICE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DNS_CHOICE`"
DEPLOYMENT_MODE="`${BUILD_HOME}/helpers/services/GetVariableValue.sh DEPLOYMENT_MODE`"
WEBSITE_URL="`${BUILD_HOME}/helpers/services/GetVariableValue.sh WEBSITE_URL`"


if ( [ "${DEPLOYMENT_MODE}" = "DEVELOPMENT" ] && [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ] )
then
	status "You are attempting to provision a managed database in development mode, this isn't supported you need to redeploy in production mode"
	/bin/touch /tmp/END_IT_ALL
fi


#dbaas_bucket="`/bin/echo ${WEBSITE_URL} | /bin/sed 's/\./-/g'`"
#dbaas_bucket="${dbaas_bucket}-${DNS_CHOICE}-dbaas"

#See if we are a managed database or not
if ( [ "${DATABASE_INSTALLATION_TYPE}" = "DBaaS" ] && ( [ "${MULTI_REGION}" = "0" ] || ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] ) ) )
then

fi

	status "Database considered to be in a running state"

	export DB_USERNAME="${DB_USERNAME}:::${db_username}"
	export DB_PASSWORD="${DB_PASSWORD}:::${db_password}"

	status ""
	status "The rest of the settings for your database are as follows:"
	status "##########################################################"
	status "USERNAME:${DB_USERNAME}"
	status "PASSWORD:${DB_PASSWORD}"
	status "HOST:${DB_IDENTIFIER}"
	status "PORT:${DB_PORT}"
	status "DB NAME:${DB_NAME}"
	status "##########################################################"
	status "If these settings look OK to you, press <enter>"

	if ( [ "`${BUILD_HOME}/helpers/services/IsHardcoreBuild.sh`" != "1" ] )
	then
		read x
	fi
else
	#If we are here then we are self managed so we generate our own username and passwords here which will be used to access
	#our self managed database everywhere in the deployment. These are generated fresh for each deployment
	DB_NAME="n`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-8 | /usr/bin/tr '[:upper:]' '[:lower:]'`n"
	DB_PASSWORD="p`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-8 | /usr/bin/tr '[:upper:]' '[:lower:]'`p"
	DB_USERNAME="u`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-8 | /usr/bin/tr '[:upper:]' '[:lower:]'`u"
	DB_IDENTIFIER="self-managed"
fi

if ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "0" ] ) 
then
	${BUILD_HOME}/services/datastore/operations/MountDatastore.sh "multi-region" "distributed"
	if ( [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "multi-region" "credentials.dat"`" != "" ] )
	then
		${BUILD_HOME}/services/datastore/operations/GetFromDatastore.sh "multi-region" "credentials.dat" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}"
		DB_NAME="`/bin/grep DB_NAME ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat | /usr/bin/awk -F'=' '{print $NF}'`"
		DB_PASSWORD="`/bin/grep DB_PASSWORD ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat| /usr/bin/awk -F'=' '{print $NF}'`"
		DB_USERNAME="`/bin/grep DB_USERNAME ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat | /usr/bin/awk -F'=' '{print $NF}'`"
		DB_PORT="`/bin/grep DB_PORT ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat | /usr/bin/awk -F'=' '{print $NF}'`"
		DB_IDENTIFIER="${DBaaS_PUBLIC_ENDPOINT}"
	else
		status "Credentials not found when making a multi region deployment to a non primary region"
		/bin/touch /tmp/END_IT_ALL
	fi
fi

if ( [ "${BUILD_FROM_SNAPSHOT}" = "1" ] && [ -f ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/db_credentials.dat ] )
then
	DB_USERNAME="`/bin/grep USERNAME ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/db_credentials.dat | /usr/bin/awk -F':' '{print $NF}'`"
	DB_PASSWORD="`/bin/grep PASSWORD ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/db_credentials.dat | /usr/bin/awk -F':' '{print $NF}'`"
	DB_NAME="`/bin/grep DBNAME ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/db_credentials.dat | /usr/bin/awk -F':' '{print $NF}'`"

	if ( [ ! -d ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots ] )
	then
		/bin/mkdir -p ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots
	fi

	/bin/echo "USERNAME:${DB_USERNAME}" > ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/db_credentials.dat.candidate
	/bin/echo "PASSWORD:${DB_PASSWORD}" >> ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/db_credentials.dat.candidate
	/bin/echo "DBNAME:${DB_NAME}" >> ${BUILD_HOME}/runtime/wholemachinesnapshots/${WEBSITE_URL}/snapshots/db_credentials.dat.candidate
fi

if ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] )
then
	/bin/echo "DB_NAME=${DB_NAME}" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat
	/bin/echo "DB_PASSWORD=${DB_PASSWORD}" >> ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat
	/bin/echo "DB_USERNAME=${DB_USERNAME}" >> ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat
	/bin/echo "DB_PORT=${DB_PORT}" >> ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat

       # multi_region_bucket="`/bin/echo "${WEBSITE_URL}" | /bin/sed 's/\./-/g'`-multi-region"
       ${BUILD_HOME}/services/datastore/operations/MountDatastore.sh "multi-region" "distributed"

       if ( [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "multi-region" "credentials.dat"`" != "" ] )
       then
	       ${BUILD_HOME}/services/datastore/operations/DeleteFromDatastore.sh "multi-region" "credentials.dat" "distributed"
       fi

       ${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "multi-region" "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/credentials.dat" "root" "distributed" "no"
fi

#Persist our credentials to the file system to be used at will      
${BUILD_HOME}/helpers/services/SetVariableValue.sh "DB_NAME=${DB_NAME}"
${BUILD_HOME}/helpers/services/SetVariableValue.sh "DB_PASSWORD=${DB_PASSWORD}"
${BUILD_HOME}/helpers/services/SetVariableValue.sh "DB_USERNAME=${DB_USERNAME}"
${BUILD_HOME}/helpers/services/SetVariableValue.sh "DB_PORT=${DB_PORT}"
${BUILD_HOME}/helpers/services/SetVariableValue.sh "DB_IDENTIFIER=${DB_IDENTIFIER}"
