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


${BUILD_HOME}/initialisation/linode/mysql/cli/VerifiySelectedEngine.sh
if [ $? != "0" ] 
then
	status "Database Engine not successfully verified"
	exit 1
fi

database_id=$(${BUILD_HOME}/initialisation/linode/mysql/cli/ObtainDatabaseID.sh)

if [ -z "$database_id" ]
then
	${BUILD_HOME}/initialisation/linode/mysql/cli/CreateDBaaSServer.sh

	${BUILD_HOME}/initialisation/linode/mysql/cli/CheckDBaaSServerStatus.sh
	if [ $? != "0" ] 
	then
		status "Could not verify DBaaS Server status"
		exit 1
	fi
else
	status "A database ${label} with id ${database_id} is already active, not provisioning a new one"
	${BUILD_HOME}/initialisation/linode/mysql/cli/UpdateDBaaSFirewall.sh ${database_id} "0.0.0.0/0"
	if ( [ "$?" != "0" ] )
	then
		status "failed to update firewall allowed ip list"
		exit 1
	fi
fi

db_payload=$(${BUILD_HOME}/initialisation/linode/mysql/cli/ObtainDatabaseDetails.sh ${database_id} ${db_name})

if [ $? -eq 0 ] && [ -n "$db_payload" ]
then
    eval "$db_payload"
    
    echo "Connected to cluster: $CLUSTER_NAME"
    echo "Host: $DB_IDENTIFIER"
    echo "Port: $DB_PORT"
else
    status "Error: Failed to retrieve database details." >&2
    exit 1
fi





#take a certificate copy in case we need it
/bin/echo "`/usr/local/bin/linode-cli databases mysql-ssl-cert ${database_id} --no-headers --no-defaults --json | /usr/bin/jq -r '.[].ca_certificate' | /usr/bin/base64 --decode`" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT

	
	


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

        available_engines="`/usr/local/bin/linode-cli databases engines --json | jq -r '.[].id'`"

        if ( [ "$?" != "0" ] || [ "${available_engines}" = "" ] )
		then
	        status "Failed to obtain list of available engines"
	        exit 1
		fi

        if ( [ "`/bin/echo ${available_engines} | /bin/grep ${engine}`" = "" ] )
        then
                status "The database engine you have selected is not available please correct and re deploy"
                exit 1
        fi

        database_id="`/usr/local/bin/linode-cli databases mysql-list --no-defaults --json | jq '.[] | select(.label | contains ("'${label}'")) | .id'`"
       
        if ( [ "$?" != "0" ] )
		then
	        status "An error occured obtaining the database id"
	        exit 1
		fi

        if ( [ "${database_id}" = "" ] )
        then
                status "Your database is being provisioned, please wait....."

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

                /usr/local/bin/linode-cli databases mysql-create --no-defaults --label "${label}" --region "${db_region}" --type "${machine_type}" --cluster_size "${cluster_size}" --engine "${engine}" --ssl_connection true --allow_list "0.0.0.0/0" --private_network.vpc_id "${vpc_id}"  --private_network.subnet_id "${subnet_id}" ${public_access}

                if ( [ "$?" != "0" ] )
				then
	                status "failed to provision database"
	                exit 1
				fi
				
                database_id=""
                status "Attempting to get database id..."
                while ( [ "${database_id}" = "" ] )
                do
                        database_id="`/usr/local/bin/linode-cli databases mysql-list --no-defaults --json | jq '.[] | select(.label | contains ("'${label}'")) | .id'`"     

                        if ( [ "${database_id}" = "" ] )
                        then
                                status "Still probing for the database id"
                                /bin/sleep 20
                        fi
                done

                status "Have got the database id which is: ${database_id}"
                status "Waiting for your database cluster ${database_id} to attain 'active' status ...this can be slow but if it takes more than 10 or 15 minutes then something must be wrong"

                db_status="inactive"
                while ( [ "${db_status}" != "active" ] )
                do
                        db_status="`/usr/local/bin/linode-cli databases mysql-list --json | jq -r '.[] | select(.label == "'${label}'").status'`"
						
                        if ( [ "${db_status}" != "active" ] )
                        then
                                /bin/sleep 20
                        fi
                done
        else
                status "A database ${label} with id ${database_id} is already active, not provisioning a new one"
                /usr/local/bin/linode-cli databases mysql-update ${database_id} --allow_list "0.0.0.0/0" --no-defaults
                if ( [ "$?" != "0" ] )
	        then
	                status "failed to update firewall allowed ip list"
	                exit 1
	        fi
        fi

		

        #Take a note of all our database details
        export CLUSTER_NAME="`/usr/local/bin/linode-cli databases mysql-list --no-defaults --json | /usr/bin/jq -r '.[] | select (.id == '${database_id}') | .label'`" 
        export DB_IDENTIFIER="`/usr/local/bin/linode-cli databases mysql-list --no-defaults --json | /usr/bin/jq -r '.[] | select (.id == '${database_id}') | .hosts.primary'`"
        export DB_USERNAME="`/usr/local/bin/linode-cli databases mysql-creds-view ${database_id} --no-defaults --json | /usr/bin/jq -r '.[].username'`"
        export DB_PASSWORD="`/usr/local/bin/linode-cli databases mysql-creds-view "${database_id}" --no-defaults --json | /usr/bin/jq -r '.[].password'`"
        export DB_PORT="`/usr/local/bin/linode-cli databases mysql-list --no-defaults --json | /usr/bin/jq -r '.[] | select (.id == '${database_id}').port'`"
        export DB_NAME="${db_name}"

        if ( [ "${db_scope_prefix}" != "" ] )
        then
                DB_IDENTIFIER="`/bin/echo ${DB_IDENTIFIER} | /bin/sed "s/^private-/${db_scope_prefix}"`"
        fi

        #take a certificate copy in case we need it
        /bin/echo "`/usr/local/bin/linode-cli databases mysql-ssl-cert ${database_id} --no-headers --no-defaults --json | /usr/bin/jq -r '.[].ca_certificate' | /usr/bin/base64 --decode`" > ${BUILD_HOME}/runtime/${CLOUDHOST}/${BUILD_IDENTIFIER}/DBaaS_CERT
fi
