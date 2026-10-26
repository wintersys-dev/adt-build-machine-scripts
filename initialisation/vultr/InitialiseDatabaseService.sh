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
	${BUILD_HOME}/helpers/services/LogStatusMessages.sh "${1}"
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
#If you are deploying to vultr provide a setting with the following format in your template
#DATABASE_DBaaS_INSTALLATION_TYPE="MySQL:DBAAS:mysql:8:lhr:vultr-dbaas-hobbyist-cc-1-25-1:testdb:testuser1:testpassword1:TestDatabase:2fb13fd1-3145-3127-7132-13f28f1912c1"
#DATABASE_DBaaS_INSTALLATION_TYPE="Postgres:DBAAS:pg:17:lhr:vultr-dbaas-hobbyist-cc-1-25-1:testdb:testuser1:testpassword1:TestDatabase:2fb13fd1-3145-3127-7132-13f28f1912c1"
#########################################################################################################

#If we are here then this is a vultr database build
if ( [ "`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /bin/grep DBAAS`" != "" ] )
then
	#extract the database's configuration detaila from DATABASE_DBaaS_INSTALLATION_TYPE
	database_type="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $1}'`"
	label="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $10}'`"
	engine="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $3}'`"
	engine_version="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $4}'`"
	db_region="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $5}'`"
	machine_type="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $6}'`"
	db_name="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $7}'`"
	db_username="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $8}'`"
	db_password="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $9}'`"
	vpc_id="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $11}'`"

	#See if an existing cluster is available
	cluster_id="`/usr/bin/vultr database list -o json | /usr/bin/jq -r '.databases[] | select (.label == "'${label}'" and .database_engine == "'${engine}'").id'`"

	new=""
	if ( [ "${cluster_id}" = "" ] )
	then
		#There was no existing cluster, so create one
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

		status "Creating  database ${label}, with engine: ${engine}, in region: ${db_region} and at size: ${machine_type} please wait..."
		/usr/bin/vultr database create --database-engine="${engine}" --database-engine-version="${engine_version}" --region="${db_region}" --plan="${machine_type}" --label="${label}" --vpc-id="${vpc_id}"

		if ( [ "$?" = "0" ] )
		then
			new="newly provisioned"
		fi
	else
		new="previously existing"
	fi

	#Wait fot the cluster to be online
	while ( [ "${cluster_id}" = "" ] )
	do
		cluster_id="`/usr/bin/vultr database list -o json | /usr/bin/jq -r '.databases[] | select (.label == "'${label}'").id'`"
		/bin/sleep 10
		status "Waiting for your new database cluster to be reponsive and online"
	done

	status "A ${new} database cluster is available with id ${cluster_id}"

	#Take a not of all our configuration settings
	export DB_USERNAME="`/usr/bin/vultr database list -o json | /usr/bin/jq -r '.databases[] | select (.id == "'${cluster_id}'").user'`"  
	export DB_PASSWORD="`/usr/bin/vultr database list -o json | /usr/bin/jq -r '.databases[] | select (.id == "'${cluster_id}'").password'`"
	export DB_IDENTIFIER="`/usr/bin/vultr database list -o json | /usr/bin/jq -r '.databases[] | select (.id == "'${cluster_id}'").host'`"
	export DB_PORT="`/usr/bin/vultr database list -o json | /usr/bin/jq -r '.databases[] | select (.id == "'${cluster_id}'").port'`"
	export DB_NAME="${db_name}"

	#Allow connections from our VPC alone
	/usr/bin/vultr database update ${cluster_id} --trusted-ips "${VPC_IP_RANGE}"
		
	status "...Waiting for the database to be in a running state"
	while ( [ "`/usr/bin/vultr database list -o json | /usr/bin/jq -r '.databases[] | select ( .label == "'${label}'" and .database_engine == "'${engine}'").status'`" != "Running" ] )
	do
		/bin/sleep 10
	done
fi

