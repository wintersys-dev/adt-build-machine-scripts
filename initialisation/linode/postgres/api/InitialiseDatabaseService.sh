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


#########################################################################################################
#DATABASE_DBaaS_INSTALLATION_TYPE="Postgres:DBAAS:<engine>:<region>:<machine_type>:<cluster_size>:<cluster_label>:<db_name>:<db_username>:<db_password>:<vpc_id>:<subnet_id>
#DATABASE_DBaaS_INSTALLATION_TYPE="Postgres:DBAAS:postgresql/14.4:nl-ams:g6-nanode-1:1:test-cluster:testdb1:testdbuser:gdhf76gdfgsh:266632:266052"
#########################################################################################################

#If we are here then this is a linode deployment
if ( [ "`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /bin/grep DBAAS`" != "" ] )
then
	#extract the database's configuration detaila from DATABASE_DBaaS_INSTALLATION_TYPE
	engine="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $3}'`"
	cluster_size="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $6}'`" 
	db_region="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $4}'`"
	machine_type="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $5}'`"
	label="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $7}'`"
	db_name="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $8}'`"
	db_username="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $9}'`"
	db_password="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $10}'`"
	vpc_id="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $11}'`"
	subnet_id="`/bin/echo ${DATABASE_DBaaS_INSTALLATION_TYPE} | /usr/bin/awk -F':' '{print $12}'`"

	if ( [ "${MULTI_REGION}" = "1" ] && [ "${PRIMARY_REGION}" = "1" ] )
	then
		public_access="--private_network.public_access true"
		db_scope_prefix="public-"
	else
		public_access="--private_network.public_access false"
		db_scope_prefix=""
		#  db_scope_prefix="private-"
	fi

	available_engines="`curl -s -H "Authorization: Bearer $TOKEN" https://api.linode.com/v4/databases/engines | jq -r '.data[].id'`"

	if ( [ "$?" != "0" ] || [ "${available_engines}" = "" ] )
	then
		status "Failed to obtain available engines"
		exit 1
	fi

	if ( [ "`/bin/echo ${available_engines} | /bin/grep ${engine}`" = "" ] )
	then
		status "The database engine you have selected is not available please correct and re deploy"
		exit 1
	fi

    database_id="`curl -s -H "Authorization: Bearer $TOKEN" -H 'X-Filter: {"label": "'$label'"}' https://api.linode.com/v4/databases/postgresql/instances | jq -r '.data[].id'`"

	if ( [ "$?" != "0" ] )
	then
		status "Failed to obtain database id"
		exit 1
	fi
	
	if ( [ "${database_id}" = "" ] )
	then   
		status "Your postgres database is being provisioned, please wait....."

		#there was no existing database, so, create one
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
				exit -1
			fi
		fi
		
		curl -X POST https://api.linode.com/v4/databases/postgresql/instances -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{ "label": "'"${label}"'", "region": "'"${db_region}"'", "type": "'"${machine_type}"'", "engine": "'"${engine}"'", "cluster_size": '"${cluster_size}"', "ssl_connection": true, "allow_list": ["0.0.0.0/0"], "private_network": { "vpc_id": '"${vpc_id}"', "subnet_id": '"${subnet_id}"' } }'

		if ( [ "$?" != "0" ] )
		then
			status "Failed to provision database"
			exit 1
		fi
		
		database_id=""
        status "Attempting to get database id..."
        while ( [ "${database_id}" = "" ] )
        do
            database_id="`curl -s -H "Authorization: Bearer $TOKEN" -H 'X-Filter: {"label": "'$label'"}' https://api.linode.com/v4/databases/postgresql/instances | jq -r '.data[].id'`"

            if ( [ "${database_id}" = "" ] )
            then
            	status "Still probing for the database id"
                /bin/sleep 20
            fi
        done

        #Wait until the database has a status of "active" which can take a while
        status "Have got the database id which is: ${database_id}"
        status "Attempting to get database id...this can be slow but if I am looking for more than 10 minutes something must be wrong"

        db_status="inactive"
        while ( [ "${db_status}" != "active" ] )
        do
			db_status="`curl -s -H "Authorization: Bearer $TOKEN" "https://api.linode.com/v4/databases/mysql/instances" | jq -r '.data[] | select(.label == "'${label}'").status'`"
            if ( [ "${db_status}" != "active" ] )
            then
            	/bin/sleep 20
            fi
        done

		#Wait for the database we have provisioned to become active
		status "Have got the database id which is: ${database_id}"
		status "Its now the wait for the database to become active (this can take a few minutes)"
		status="inactive"

		while ( [ "${status}" != "active" ] ) 
		do
			/bin/sleep 20
			status="`curl -s -H "Authorization: Bearer $TOKEN" "https://api.linode.com/v4/databases/postgresql/instances" | jq -r '.data[] | select(.label == "'${label}'").status'`"
		done
	else	
		#Open up during the build and tighten up afterwards
		curl -s -X PUT "https://api.linode.com/v4/databases/postgresql/instances/${database_id}" -H "Authorization: Bearer $TOKEN"  -H "Content-Type: application/json"  -d '{"allow_list": ["0.0.0.0/0"]}'

	fi

	#take a note of all our configuration settings
	export CLUSTER_NAME="`curl -s -X GET "https://api.linode.com/v4/databases/postgresql/instances/${database_id}" -H "Authorization: Bearer $TOKEN" | jq -r '.label'`"
	export DB_IDENTIFIER="`curl -s -X GET "https://api.linode.com/v4/databases/postgresql/instances/${database_id}" -H "Authorization: Bearer $TOKEN" | jq -r '.hosts.primary'`"
	export DB_USERNAME="`curl -s -X GET "https://api.linode.com/v4/databases/postgresql/instances/${database_id}/credentials"  -H "Authorization: Bearer $TOKEN" | jq -r '.username'`"
	export DB_PASSWORD="`curl -s -X GET "https://api.linode.com/v4/databases/postgresql/instances/${database_id}/credentials"  -H "Authorization: Bearer $TOKEN" | jq -r '.password'`"
	export DB_PORT="`/usr/local/bin/linode-cli databases postgresql-list --no-defaults --json | /usr/bin/jq -r '.[] | select (.id == '${database_id}').port'`"
	export DB_PORT="`curl -s -H "Authorization: Bearer $TOKEN"  https://api.linode.com/v4/databases/postgresql/instances/${database_id} | jq -r '.port'`"
	export DB_NAME="${db_name}"

	if ( [ "${db_scope_prefix}" != "" ] )
	then
		DB_IDENTIFIER="`/bin/echo ${DB_IDENTIFIER} | /bin/sed "s/^private-/${db_scope_prefix}"`"
	fi

	#grab the cert, why not, we might need it
    /bin/echo "`curl -s -H "Authorization: Bearer ${TOKEN}"  "https://api.linode.com/v4/databases/postgresql/instances/${database_id}/ssl" | jq -r '.ca_certificate' | base64 --decode`" > "${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT"

fi
