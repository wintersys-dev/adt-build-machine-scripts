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

#########################################################################################################
#If you are deploying to exoscale provide a setting with the following format in your template
#DATABASE_DBaaS_INSTALLATION_TYPE="MySQL:DBAAS:mysql:ch-gva-2:hobbyist-2:testdb1:testuser1:testpassword1"
#DATABASE_DBaaS_INSTALLATION_TYPE="Postgres:DBAAS:pg:ch-gva-2:hobbyist-2:testdb1:testuser1:testpassword1"
#If you need to you can turn off termination protection as in the following example:
#exo dbaas update testdb1 -z ch-gva-2 --termination-protection=false
#########################################################################################################

#If we are here then this is an exoscale deployment
if ( [ "`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /bin/grep DBAAS`" != "" ] )
then
	#extract the database's configuration detaila from DATABASE_DBaaS_INSTALLATION_TYPE

	database_details="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /bin/sed 's/^.*DBAAS://g'`"
	database_engine="`/bin/echo ${database_details} | /usr/bin/awk -F':' '{print $1}'`"
	database_region="`/bin/echo ${database_details} | /usr/bin/awk -F':' '{print $2}'`"
	database_size="`/bin/echo ${database_details} | /usr/bin/awk -F':' '{print $3}'`"
	db_name="`/bin/echo ${database_details} | /usr/bin/awk -F':' '{print $4}'`"
	db_username="`/bin/echo ${database_details} | /usr/bin/awk -F':' '{print $5}'`"
	db_password="`/bin/echo ${database_details} | /usr/bin/awk -F':' '{print $6}'`"

	if ( [ ! -f ${BUILD_HOME}/runtime/${CLOUDHOST}/.DBAAS_CREDENTIALS ] )
	then
		if ( [ "`${BUILD_HOME}/services/datastore/operations/ListFromDatastore.sh "dbaas" ".DBAAS_CREDENTIALS"`" != "" ] )
		then
			${BUILD_HOME}/services/datastore/operations/GetFromDatastore.sh "dbaas" ".DBAAS_CREDENTIALS" "${BUILD_HOME}/runtime/${CLOUDHOST}"
		fi
	fi

	#See if there is an existing database that we can use
	existing_db_name="`/usr/bin/exo dbaas list -O json | /usr/bin/jq -r '.[]  | select (.name=="'${db_name}'" and .type=="'${database_engine}'").name'`"   
	new=""
	if ( [ "${existing_db_name}" = "" ] )
	then
		#If we are here there is no existing database and we need to create one
		if ( [ "${DB_INSTALL_MODE}" = "0" ] || [ "${DB_INSTALL_MODE}" = "2" ] )
		then
			status "You must have DB_INSTALL_MODE set to 1 for a newly provisioned database"
			status "Do want me to set DB_INSTALL_MODE to '1' so that the build will continue (Y|y) otherwise I will have to exit"
			response="Y"
			if ( [ "`${BUILD_HOME}/helpers/services/IsHardcoreBuild.sh`" != "1" ] )
			then
				read response
			fi

			if ( [ "${response}" = "y" ] || [ "${response}" = "Y" ] )
			then
				DB_INSTALL_MODE="1"
				else
					status "Can't continue with installation, DB_INSTALL_MODE not set as required"
					exit 1
				fi
			fi

			admin_username="adt-dbadmin"
			admin_password="`/usr/bin/openssl rand -base64 32 | /usr/bin/tr -cd 'a-zA-Z0-9' | /usr/bin/cut -b 1-12`"

			if ( [ -f ${BUILD_HOME}/runtime/${CLOUDHOST}/.DBAAS_CREDENTIALS ] )	
			then
				/bin/cp ${BUILD_HOME}/runtime/${CLOUDHOST}/.DBAAS_CREDENTIALS ${BUILD_HOME}/runtime/${CLOUDHOST}/.DBAAS_CREDENTIALS.$$
			fi
				
			/bin/echo "DB ADMIN USERNAME: ${admin_username}" > ${BUILD_HOME}/runtime/${CLOUDHOST}/.DBAAS_CREDENTIALS
			/bin/echo "DB ADMIN PASSWORD: ${admin_password}" >> ${BUILD_HOME}/runtime/${CLOUDHOST}/.DBAAS_CREDENTIALS

			${BUILD_HOME}/services/datastore/operations/MountDatastore.sh "dbaas" "distributed"
			${BUILD_HOME}/services/datastore/operations/PutToDatastore.sh "dbaas" "${BUILD_HOME}/runtime/${CLOUDHOST}/.DBAAS_CREDENTIALS" "root" "distributed" "no"

			status "Creating  database ${db_name}, with engine: ${database_engine}, in region: ${database_region} and at size: ${database_size} please wait..."
			if ( [ "${database_engine}" = "mysql" ] )
			then
				/usr/bin/exo dbaas create ${database_engine} ${database_size} ${db_name} --zone ${database_region} --mysql-admin-username "${admin_username}" --mysql-admin-password  "${admin_password}"
			elif ( [ "${database_engine}" = "pg" ] )
			then
				/usr/bin/exo dbaas create ${database_engine} ${database_size} ${db_name} --zone ${database_region} --pg-admin-username "${admin_username}" --pg-admin-password  "${admin_password}"
			fi

			if ( [ "$?" = "0" ] )
			then
				new="newly provisioned"
			fi
		else
			new="previously existing"
			admin_username="`/bin/grep "USERNAME" ${BUILD_HOME}/runtime/${CLOUDHOST}/.DBAAS_CREDENTIALS | /usr/bin/awk '{print $NF}'`"
			admin_password="`/bin/grep "PASSWORD" ${BUILD_HOME}/runtime/${CLOUDHOST}/.DBAAS_CREDENTIALS | /usr/bin/awk '{print $NF}'`"
		fi

		#Wait for the database to be in a "running" state
		status "Waiting for your new database cluster to be responsive and online (this may take a little while)"
		while ( [ "`/usr/bin/exo dbaas show ${db_name} -O json | /usr/bin/jq -r 'select (.name == "'${db_name}'" and .type=="'${database_engine}'").state'`" != "running" ] )
		do
			/bin/sleep 10
		done

		status ""
		status "Database with name ${db_name} is now running"
		status ""

		#Take note of all of the database's configuration details
		export DB_USERNAME="${admin_username}"
		export DB_PASSWORD="${admin_password}"
		export DATABASE_INSTALLATION_TYPE="DBaaS"
		export DB_IDENTIFIER="`/usr/bin/exo -O json dbaas show --zone ${database_region} ${db_name} | /usr/bin/jq -r ".${database_engine}.uri_params.host"`"
		export DB_NAME="${db_name}"
		export DB_PORT="`/usr/bin/exo -O json dbaas show --zone ${database_region} ${db_name} | /usr/bin/jq -r ".${database_engine}.uri_params.port"`" 
		export DATABASE_REGION="${database_region}"

			#Open up fully until we are installed and then tighten up the firewall later on from the autoscaler
			#   if ( [ "${database_engine}" = "mysql" ] )
			#   then 
			#           /usr/bin/exo dbaas update --quiet --zone ${database_region} ${db_name} --mysql-ip-filter="0.0.0.0/0"
			#   elif ( [ "${database_engine}" = "pg" ] )
			#   then
			#           /usr/bin/exo dbaas update --quiet --zone ${database_region} ${db_name} --pg-ip-filter="0.0.0.0/0"
			#   fi

		status "Please go to the Exoscale GUI system of your new database and switch off 'STRICT_ALL_TABLES' and 'sql_require_primary_key'"
		status "Press <enter> once this is done, failure to do this could result in a blocked/failed installation"
		read x

		#record a certificate in case we need it
		/usr/bin/exo dbaas ca-certificate > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT
	fi
fi

